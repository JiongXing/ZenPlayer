"""只向独立模拟器验证 App 写入可重复的静音收听样本；拒绝其他 bundle。"""
import argparse
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import time
import wave

BUNDLE_ID = "com.jxing.ZenPlayer.StageValidation"


def seed(device):
    container = Path(subprocess.check_output([
        "xcrun", "simctl", "get_app_container", device, BUNDLE_ID, "data"
    ], text=True).strip())
    metadata = plistlib.loads((container / ".com.apple.mobile_container_manager.metadata.plist").read_bytes())
    if metadata.get("MCMMetadataIdentifier") != BUNDLE_ID:
        raise RuntimeError("验证容器身份不符，拒绝写入")
    subprocess.run(["xcrun", "simctl", "terminate", device, BUNDLE_ID], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    downloads = container / "Documents/ZenPlayerDownloads"
    downloads.mkdir(parents=True, exist_ok=True)
    with wave.open(str(downloads / "stage-validation.wav"), "wb") as media:
        media.setnchannels(1)
        media.setsampwidth(2)
        media.setframerate(8000)
        media.writeframes(bytes(8000 * 2 * 180))
    context = {
        "episode": {"id": 900001, "num": "UI-001", "title": "UI 靜音驗證：長標題用於確認迷你播放器截斷顯示後仍保留完整可存取名稱", "episode": "1",
                    "mp4Url": "", "vodUrl": "", "mp3Url": "https://stage-validation.invalid/silent.wav",
                    "coverUrl": "", "textUrl": "", "filesize": 2880044, "duration": 180000},
        "serverUrl": "https://stage-validation.invalid/", "preferredMediaType": "audio"
    }
    key = "900001|https://stage-validation.invalid/"
    now = time.time()
    progress = {"schemaVersion": 1, "legacyKey": key, "context": context, "positionSeconds": 30,
                "durationSeconds": 180, "state": "inProgress", "lastListenedAt": now - 978307200,
                "updatedAt": now - 978307200, "revision": 1, "origin": "ui-validation"}
    records = container / "Library/Application Support/PlaybackProgress/v1/records"
    records.mkdir(parents=True, exist_ok=True)
    (records / (hashlib.sha256(key.encode()).hexdigest() + ".json")).write_text(json.dumps(progress))
    manifest_path = downloads / "download_manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"version": 2, "records": {}}
    if manifest.get("version") != 2 or not isinstance(manifest.get("records"), dict):
        raise RuntimeError("验证 App 下载索引格式不符，保留原文件并停止")
    manifest["records"]["900001_mp3"] = {
        "episodeId": 900001, "type": "mp3", "remoteURL": context["episode"]["mp3Url"],
        "destinationRelativePath": "stage-validation.wav", "playbackContext": context,
        "status": "completed", "progress": 1, "completedAt": now, "updatedAt": now
    }
    manifest_path.write_text(json.dumps(manifest))
    print("Seeded isolated UI fixture:", BUNDLE_ID)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", help="已启动的隔离验证 App 所在模拟器 UUID")
    seed(parser.parse_args().device)
