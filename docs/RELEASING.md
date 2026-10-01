# Building and releasing

## What runs automatically

| Workflow | When | What it does |
|---|---|---|
| **CI** (`.github/workflows/ci.yml`) | every push and pull request | unit tests and bot simulations, a smoke test that drives the real screens with taps, drags and swipes on a virtual display (screenshots are uploaded), then builds Android, Windows, Linux and Web as `0.1.0-dev.<run>` |
| **Release** (`.github/workflows/release.yml`) | pushing a tag `v1.2.3`, or running it by hand | the same tests and builds, stamped with the release version, published as a GitHub release with the changelog section as notes |

The building blocks are reusable: `test.yml`, `build.yml` and the
`setup-godot` action (downloads and caches Godot 4.7.2 and the export
templates). Every build is also an artifact of its workflow run.

## Making a release

1. Add a `## [1.2.3] - YYYY-MM-DD` section to `CHANGELOG.md`.
2. Set `config/version="1.2.3"` in `project.godot`.
3. Commit, then tag and push:
   ```sh
   git tag v1.2.3
   git push origin v1.2.3
   ```
   Or open **Actions → Release → Run workflow** and enter `1.2.3`, which
   creates the tag on the selected branch.

Versions with a suffix (`1.2.3-beta.1`) become GitHub pre-releases. The
Android version code is derived from the version: `1.2.3` → `10203`.

## Android signing

- **Without secrets** (the default), the APK is a debug build signed with the
  shared test key in `tools/android/debug.keystore`. That key is public on
  purpose: it only lets testers install updates over older test builds. Never
  use it for the Play Store.
- **For real releases**, create a private key once and add three repository
  secrets (Settings → Secrets and variables → Actions):
  ```sh
  keytool -genkeypair -v -keystore release.keystore -alias passtheplate \
    -keyalg RSA -keysize 2048 -validity 10000
  base64 -w0 release.keystore   # -> ANDROID_KEYSTORE_BASE64
  ```
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS` (`passtheplate`) and
  `ANDROID_KEYSTORE_PASSWORD`. The build then makes a release-signed APK.
  Keep `release.keystore` safe: Android only accepts updates signed with the
  same key.

## Building locally

```sh
# Godot 4.7.2 with export templates installed; Android also needs the SDK and a JDK.
GODOT=/path/to/godot ANDROID_HOME=~/Android/Sdk JAVA_HOME=/usr/lib/jvm/java-17 \
  tools/export.sh android windows linux web
```

The files land in `build/release/`. Note that `tools/export.sh` stamps the
version into `project.godot` and `export_presets.cfg`.
