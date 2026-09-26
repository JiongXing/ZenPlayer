#!/usr/bin/env python3
"""在保持 sandbox 的独立 macOS 验证 App 中运行窗口／退出回归。"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

BUNDLE_ID = "com.jxing.ZenPlayer.MacStageValidation"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="仓库外不存在的输出目录")
    parser.add_argument("--package-cache", type=Path, help="可复用的 Xcode SourcePackages 路径")
    parser.add_argument("--only-testing", help="只运行指定的 MacStageUITests 测试方法")
    parser.add_argument("--jump-input", choices=("12", "0012", "第１２集"), default="0012",
                        help="搜索用例的第 12 集输入形式；Unicode 形式在本机 Xcode 存在事件合成超时")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    if args.only_testing and args.only_testing not in re.findall(
            r"func (test\w+)\(", (repo / "ZenPlayerUITests/MacStageUITests.swift").read_text()):
        parser.error("only-testing 必须是现有 Mac UI 测试方法名")
    output = args.output.expanduser().resolve()
    if output == repo or repo in output.parents:
        parser.error("输出必须在仓库外")
    cache = args.package_cache.expanduser().resolve() if args.package_cache else None
    if cache and not cache.is_dir():
        parser.error("package-cache 目录不存在")
    output.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location("stage_ui", repo / "Scripts/run-stage-ui-tests.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    work = runner.prepare_project(repo, output)
    path = work / "ZenPlayer.xcodeproj/project.pbxproj"
    project = plistlib.loads(path.read_bytes())
    objects = project["objects"]
    for target in objects.values():
        if target.get("isa") != "PBXNativeTarget" or target["name"] not in ("ZenPlayer", "StageUITests"):
            continue
        for config in objects[target["buildConfigurationList"]]["buildConfigurations"]:
            settings = objects[config]["buildSettings"]
            # macOS 有条件 bundle 覆盖项，必须一并移除，不能只更改基础值。
            for key in list(settings):
                if key.startswith("PRODUCT_BUNDLE_IDENTIFIER"):
                    del settings[key]
            settings["PRODUCT_BUNDLE_IDENTIFIER"] = BUNDLE_ID + (".uitests" if target["name"] == "StageUITests" else "")
            settings.update(CODE_SIGNING_ALLOWED="YES", CODE_SIGN_IDENTITY="-", CODE_SIGN_STYLE="Manual")
            if target["name"] == "ZenPlayer":
                settings["ENABLE_APP_SANDBOX"] = "YES"
            else:
                settings.update(SDKROOT="macosx", SUPPORTED_PLATFORMS="macosx", MACOSX_DEPLOYMENT_TARGET="14.0")
                settings.pop("IPHONEOS_DEPLOYMENT_TARGET", None)
                settings.pop("TARGETED_DEVICE_FAMILY", None)
    path.write_bytes(plistlib.dumps(project, sort_keys=False))
    shutil.copy2(repo / "ZenPlayerUITests/MacStageUITests.swift", work / "StageUITests/StageUITests.swift")
    shutil.copy2(repo / "ZenPlayerUITests/MacStageFixture.swift", work / "ZenPlayer/MacStageFixture.swift")
    scheme_path = work / "ZenPlayer.xcodeproj/xcshareddata/xcschemes/ZenPlayer.xcscheme"
    scheme = ET.parse(scheme_path)
    test_action = scheme.getroot().find("TestAction")
    if test_action is None:
        raise RuntimeError("临时 scheme 缺少 TestAction")
    test_action.set("shouldUseLaunchSchemeArgsEnv", "NO")
    variables = test_action.find("EnvironmentVariables")
    if variables is None:
        variables = ET.SubElement(test_action, "EnvironmentVariables")
    ET.SubElement(variables, "EnvironmentVariable", key="ZENPLAYER_JUMP_INPUT",
                  value=args.jump_input, isEnabled="YES")
    scheme.write(scheme_path, encoding="utf-8", xml_declaration=True)
    app_source = work / "ZenPlayer/ZenPlayerApp.swift"
    original = app_source.read_text()
    marker = "@State private var playbackSession = PlayerViewModel()"
    if original.count(marker) != 1:
        raise RuntimeError("App 初始化结构变化，拒绝猜测样本注入位置")
    app_source.write_text(original.replace(marker, """@State private var playbackSession: PlayerViewModel = {
        MacStageFixture.seedIfRequested()
        return PlayerViewModel()
    }()"""))
    # 只在临时副本里添加播种入口；生产源码和签名配置不变。
    (output / "context.json").write_text(json.dumps({
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "destination": "platform=macOS", "bundleID": BUNDLE_ID,
        "onlyTesting": args.only_testing,
        "jumpInput": args.jump_input,
        "bootstrap": "temporary App initializer seeds its own sandbox before creating PlayerViewModel",
        "projectSHA256": hashlib.sha256((repo / "ZenPlayer.xcodeproj/project.pbxproj").read_bytes()).hexdigest(),
        "sha256": {str(p.relative_to(repo)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for directory in ("ZenPlayer", "ZenPlayerUITests", "Scripts")
                   for p in sorted((repo / directory).rglob("*")) if p.is_file() and "__pycache__" not in p.parts}
    }, ensure_ascii=False, indent=2) + "\n")
    command = ["xcodebuild", "-project", str(work / "ZenPlayer.xcodeproj"), "-scheme", "ZenPlayer",
               "-destination", "platform=macOS", "-derivedDataPath", str(output / "derived-data"),
               "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never"]
    if cache:
        command += ["-clonedSourcePackagesDirPath", str(cache)]
    if args.only_testing:
        command += ["-only-testing:StageUITests/StageUITests/" + args.only_testing]
    runner.run_logged(command + ["-resultBundlePath", str(output / "build.xcresult"), "build-for-testing"], work, output / "build.log")
    app = output / "derived-data/Build/Products/Debug/ZenPlayer.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise RuntimeError("验证 App bundle 不符，拒绝启动")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    entitlements = subprocess.check_output(["codesign", "-d", "--entitlements", ":-", str(app)], stderr=subprocess.DEVNULL)
    (output / "entitlements.plist").write_bytes(entitlements)
    if plistlib.loads(entitlements).get("com.apple.security.app-sandbox") is not True:
        raise RuntimeError("验证 App 未启用 sandbox，拒绝启动")
    runner.run_logged(command + ["-resultBundlePath", str(output / "tests.xcresult"), "test-without-building"], work, output / "test.log")
    print("macOS 隔离 UI 验证完成：", output)


if __name__ == "__main__":
    main()
