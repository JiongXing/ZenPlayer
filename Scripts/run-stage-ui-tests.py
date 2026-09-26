#!/usr/bin/env python3
"""复制生产源码，在独立模拟器 App／数据容器中运行阶段 UI 回归。"""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

BUNDLE_ID = "com.jxing.ZenPlayer.StageValidation"


def prepare_project(repo, output):
    work = output / "project"
    work.mkdir()
    for name in ("ZenPlayer", "ZenPlayer.xcodeproj", "ZenPlayerTests"):
        shutil.copytree(repo / name, work / name)
    project_path = work / "ZenPlayer.xcodeproj/project.pbxproj"
    project_data = json.loads(subprocess.check_output([
        "plutil", "-convert", "json", "-o", "-", str(project_path)
    ]))
    objects = project_data["objects"]
    project = objects[project_data["rootObject"]]
    app = next(key for key, value in objects.items()
               if value.get("isa") == "PBXNativeTarget" and value.get("name") == "ZenPlayer")
    for config in objects[objects[app]["buildConfigurationList"]]["buildConfigurations"]:
        settings = objects[config]["buildSettings"]
        settings["PRODUCT_BUNDLE_IDENTIFIER"] = BUNDLE_ID
        settings["INFOPLIST_KEY_CFBundleDisplayName"] = "ZenPlayer Validation"
        settings["CODE_SIGNING_ALLOWED"] = "NO"

    def add(object_name, **values):
        key = hashlib.sha1(("StageUI:" + object_name).encode()).hexdigest()[:24].upper()
        if key in objects:
            raise RuntimeError("验证工程对象 ID 冲突：" + object_name)
        objects[key] = values
        return key

    source = add("source", isa="PBXFileReference", lastKnownFileType="sourcecode.swift",
                 path="StageUITests/StageUITests.swift", sourceTree="SOURCE_ROOT")
    build = add("build", isa="PBXBuildFile", fileRef=source)
    product = add("product", isa="PBXFileReference", explicitFileType="wrapper.cfbundle",
                  path="StageUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    sources = add("sources", isa="PBXSourcesBuildPhase", buildActionMask=2147483647,
                  files=[build], runOnlyForDeploymentPostprocessing=0)
    frameworks = add("frameworks", isa="PBXFrameworksBuildPhase", buildActionMask=2147483647,
                     files=[], runOnlyForDeploymentPostprocessing=0)
    settings = {
        "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + ".uitests",
        "TEST_TARGET_NAME": "ZenPlayer", "GENERATE_INFOPLIST_FILE": "YES",
        "SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos",
        "SUPPORTED_PLATFORMS": "iphonesimulator", "TARGETED_DEVICE_FAMILY": "1,2",
        "CODE_SIGNING_ALLOWED": "NO"
    }
    configs = [add(name, isa="XCBuildConfiguration", name=name, buildSettings=settings.copy())
               for name in ("Debug", "Release")]
    config_list = add("configs", isa="XCConfigurationList", buildConfigurations=configs,
                      defaultConfigurationIsVisible=0, defaultConfigurationName="Debug")
    proxy = add("proxy", isa="PBXContainerItemProxy", containerPortal=project_data["rootObject"],
                proxyType=1, remoteGlobalIDString=app, remoteInfo="ZenPlayer")
    dependency = add("dependency", isa="PBXTargetDependency", target=app, targetProxy=proxy)
    target = add("target", isa="PBXNativeTarget", name="StageUITests", productName="StageUITests",
                 productType="com.apple.product-type.bundle.ui-testing", productReference=product,
                 buildConfigurationList=config_list, buildPhases=[sources, frameworks],
                 buildRules=[], dependencies=[dependency])
    project["targets"].append(target)
    project["attributes"].setdefault("TargetAttributes", {})[target] = {"TestTargetID": app}
    objects[project["mainGroup"]]["children"].append(source)
    objects[project["productRefGroup"]]["children"].append(product)
    project_path.write_bytes(plistlib.dumps(project_data, sort_keys=False))

    scheme = work / "ZenPlayer.xcodeproj/xcshareddata/xcschemes/ZenPlayer.xcscheme"
    tree = ET.parse(scheme)
    testables = tree.find("TestAction/Testables")
    if testables is None:
        raise RuntimeError("ZenPlayer scheme 缺 Testables")
    testables.clear()
    reference = ET.SubElement(testables, "TestableReference", {"skipped": "NO", "parallelizable": "NO"})
    ET.SubElement(reference, "BuildableReference", {
        "BuildableIdentifier": "primary", "BlueprintIdentifier": target,
        "BuildableName": "StageUITests.xctest", "BlueprintName": "StageUITests",
        "ReferencedContainer": "container:ZenPlayer.xcodeproj"
    })
    tree.write(scheme, encoding="utf-8", xml_declaration=True)
    (work / "StageUITests").mkdir()
    shutil.copy2(repo / "ZenPlayerUITests/StageUITests.swift", work / "StageUITests/StageUITests.swift")
    # 保存播种器快照，运行期间仓库继续编辑也不改变本次输入。
    shutil.copy2(repo / "ZenPlayerUITests/seed_fixture.py", output / "seed_fixture.py")
    return work


def run_logged(command, directory, log_path):
    print("执行：", " ".join(map(str, command)), flush=True)
    with log_path.open("w") as log:
        result = subprocess.run(command, cwd=directory, stdout=log, stderr=subprocess.STDOUT)
    print(f"exit={result.returncode}；日志：{log_path}", flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", required=True, help="platform=iOS Simulator,id=<available UUID>")
    parser.add_argument("--output", type=Path, required=True, help="仓库外的新输出目录，必须不存在")
    parser.add_argument("--package-cache", type=Path, help="可复用的 Xcode SourcePackages 路径")
    args = parser.parse_args()
    match = re.fullmatch(r"platform=iOS Simulator,id=([0-9a-fA-F-]{36})", args.destination)
    if not match:
        parser.error("只允许以明确 UUID 指定 iOS Simulator，不允许真实设备")
    device_id = match.group(1).upper()
    available = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
    device = next((item for devices in available["devices"].values() for item in devices
                   if item["udid"] == device_id), None)
    if device is None:
        parser.error("找不到指定的可用模拟器")
    repo = Path(__file__).resolve().parents[1]
    output = args.output.expanduser().resolve()
    if output == repo or repo in output.parents:
        parser.error("输出必须位于仓库外，避免将生成工程写进待提交范围")
    cache = args.package_cache.expanduser().resolve() if args.package_cache else None
    if cache and not cache.is_dir():
        parser.error("package-cache 目录不存在")
    output.mkdir(parents=True, exist_ok=False)
    work = prepare_project(repo, output)
    (output / "context.json").write_text(json.dumps({
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "destination": args.destination, "device": device, "bundleID": BUNDLE_ID,
        "source": "current workspace; copied production source without behavior changes",
        "sha256": {str(path.relative_to(work)): hashlib.sha256(path.read_bytes()).hexdigest()
                   for folder in ("ZenPlayer", "StageUITests")
                   for path in sorted((work / folder).rglob("*")) if path.is_file()}
    }, ensure_ascii=False, indent=2) + "\n")
    command = ["xcodebuild", "-project", str(work / "ZenPlayer.xcodeproj"), "-scheme", "ZenPlayer",
               "-destination", args.destination, "-destination-timeout", "15",
               "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
               "-derivedDataPath", str(output / "derived-data")]
    if cache:
        command += ["-clonedSourcePackagesDirPath", str(cache)]
    run_logged(command + ["-resultBundlePath", str(output / "build.xcresult"), "build-for-testing"],
               work, output / "build.log")
    if device["state"] != "Booted":
        subprocess.run(["xcrun", "simctl", "boot", device_id], check=True)
    run_logged(["xcrun", "simctl", "bootstatus", device_id, "-b"], work, output / "boot.log")
    app = output / "derived-data/Build/Products/Debug-iphonesimulator/ZenPlayer.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise RuntimeError("构建产物不是独立验证 App，拒绝安装和写数据")
    subprocess.run(["xcrun", "simctl", "install", device_id, str(app)], check=True)
    run_logged([sys.executable, str(output / "seed_fixture.py"), device_id], work, output / "fixture.log")
    run_logged(command + ["-resultBundlePath", str(output / "tests.xcresult"), "test-without-building"],
               work, output / "test.log")
    print("隔离 UI 验证完成：", output, flush=True)


if __name__ == "__main__":
    main()
