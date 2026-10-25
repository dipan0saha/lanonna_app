"""apps/mobile/scripts/flutter_build_apk.sh: every APK build carries the build stamp."""

import os
import re
import shutil
import subprocess
from pathlib import Path

_REPO = Path(__file__).resolve().parents[2]
_MOBILE = _REPO / "apps" / "mobile"
_WRAPPER = _MOBILE / "scripts" / "flutter_build_apk.sh"


def _run(tmp_path, *args, env_extra=None, copy_to=None):
    """Runs the wrapper with a fake `flutter` that prints its arguments."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    fake = bin_dir / "flutter"
    fake.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n')
    fake.chmod(0o755)
    wrapper = _WRAPPER
    if copy_to is not None:
        scripts = copy_to / "apps" / "mobile" / "scripts"
        scripts.mkdir(parents=True)
        for name in (
            "flutter_build_apk.sh",
            "flutter_build_appbundle.sh",
            "flutter_build_stamp.sh",
            "build_stamp.sh",
            "derive_android_version_code.sh",
            "android_release_guard.sh",
        ):
            shutil.copy2(_MOBILE / "scripts" / name, scripts / name)
        wrapper = scripts / "flutter_build_apk.sh"
        shutil.copytree(_MOBILE / "flavors", copy_to / "apps" / "mobile" / "flavors")
    env = {k: v for k, v in os.environ.items() if k not in ("BUILD_NUMBER", "ANDROID_RELEASE_BUILD")}
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(wrapper), *args],
        check=False,
        capture_output=True,
        text=True,
        env=env,
    )


def _head_sha():
    return subprocess.run(
        ["git", "-C", str(_REPO), "rev-parse", "--short", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _expected_build_number():
    ts = int(
        subprocess.run(
            ["git", "-C", str(_REPO), "log", "-1", "--format=%ct", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    )
    return str(ts - 1_577_836_800)


def test_dev_build_gets_git_sha_and_build_number(tmp_path):
    result = _run(tmp_path, "--debug", "--dart-define-from-file=flavors/dev.json")
    assert result.returncode == 0, result.stderr
    args = result.stdout.splitlines()
    assert args[0] == "build" and args[1] == "apk"
    assert f"--dart-define=BUILD_GIT_SHA={_head_sha()}" in args
    expected = _expected_build_number()
    assert f"--dart-define=BUILD_NUMBER={expected}" in args
    assert f"--build-number={expected}" in args
    assert args[-2:] == ["--debug", "--dart-define-from-file=flavors/dev.json"]


def test_explicit_build_number_wins(tmp_path):
    result = _run(tmp_path, "--release", env_extra={"BUILD_NUMBER": "4242"})
    assert result.returncode == 0, result.stderr
    assert "--build-number=4242" in result.stdout.splitlines()
    assert "--dart-define=BUILD_NUMBER=4242" in result.stdout.splitlines()


def test_dev_build_without_git_still_builds_with_unknown_stamp(tmp_path):
    result = _run(tmp_path, "--debug", copy_to=tmp_path / "nogit", env_extra={"GIT_CEILING_DIRECTORIES": str(tmp_path)})
    assert result.returncode == 0, result.stderr
    args = result.stdout.splitlines()
    assert "--dart-define=BUILD_GIT_SHA=unknown" in args
    assert not any(a.startswith("--build-number=") for a in args)


def test_prod_build_without_git_fails_loudly(tmp_path):
    result = _run(
        tmp_path,
        "--release",
        "--dart-define-from-file=flavors/prod.json",
        copy_to=tmp_path / "nogit",
        env_extra={"GIT_CEILING_DIRECTORIES": str(tmp_path)},
    )
    assert result.returncode != 0
    assert "BUILD_GIT_SHA is required" in result.stderr
    assert "build" not in result.stdout.splitlines()


_DIRECT_BUILD = re.compile(r"flutter\s+build\s+(apk|appbundle)\b|gradlew\S*\s+(\S+\s+)*:?(app:)?(assemble|bundle)")


def test_every_android_build_path_uses_a_wrapper():
    """No tracked script, doc or config builds an APK/AAB without the stamp (and release guard)."""
    wrappers = {
        "apps/mobile/scripts/flutter_build_apk.sh",
        "apps/mobile/scripts/flutter_build_appbundle.sh",
        "apps/mobile/scripts/flutter_build_stamp.sh",
    }
    tracked = subprocess.run(
        ["git", "-C", str(_REPO), "ls-files"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    direct = []
    for path in tracked:
        if path in wrappers or path.startswith("scripts/tests/"):
            continue
        if Path(path).suffix not in {".sh", ".md", ".py", ".yaml", ".yml", ".toml", ".json", ".kts", ".gradle", ""}:
            continue
        file = _REPO / path
        if not file.is_file():
            continue
        try:
            text = file.read_text()
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if _DIRECT_BUILD.search(line):
                direct.append(f"{path}:{number}")
    assert direct == [], f"build via scripts/flutter_build_apk.sh or scripts/flutter_build_appbundle.sh: {direct}"
    for script in (
        _MOBILE / "maestro" / "scripts" / "build-install.sh",
        _REPO / "scripts" / "ship_release_apk_to_drive.sh",
        _REPO / "scripts" / "ship_release_apk_x86_64_to_drive.sh",
    ):
        assert "flutter_build_apk.sh" in script.read_text(), script
