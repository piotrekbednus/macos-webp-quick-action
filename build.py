#!/usr/bin/env python3
"""Build the .workflow bundles in workflows/ from the scripts in src/.

Edit a script in src/, run `python3 build.py`, commit both. The bundles are
committed so people can install without running anything.
"""
import plistlib
import shutil
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ACTIONS = {
    "Convert to WebP": "convert-to-webp.sh",
    "Convert to AVIF": "convert-to-avif.sh",
}
NAMESPACE = uuid.UUID("6f1c2b1e-9a51-4b8e-9d3a-2f6a0c1d7e55")


def build(name: str, script_file: str) -> None:
    script = (ROOT / "src" / script_file).read_text()
    out = ROOT / "workflows" / f"{name}.workflow" / "Contents"
    if out.parent.exists():
        shutil.rmtree(out.parent)
    out.mkdir(parents=True)

    with open(ROOT / "template" / "document.wflow", "rb") as fh:
        wf = plistlib.load(fh)
    action = wf["actions"][0]["action"]
    params = action["ActionParameters"]
    params["COMMAND_STRING"] = script
    params["shell"] = "/bin/zsh"
    params["inputMethod"] = 1  # pass selected files as arguments
    # Stable UUIDs so a rebuild without changes produces no diff.
    for key in ("InputUUID", "OutputUUID", "UUID"):
        action[key] = str(uuid.uuid5(NAMESPACE, f"{name}/{key}")).upper()
    with open(out / "document.wflow", "wb") as fh:
        plistlib.dump(wf, fh)

    with open(ROOT / "template" / "Info.plist", "rb") as fh:
        info = plistlib.load(fh)
    service = info["NSServices"][0]
    service["NSMenuItem"]["default"] = name
    service["NSSendFileTypes"] = ["public.image"]
    with open(out / "Info.plist", "wb") as fh:
        plistlib.dump(info, fh)
    print(f"built workflows/{name}.workflow")


if __name__ == "__main__":
    for name, script_file in ACTIONS.items():
        build(name, script_file)
