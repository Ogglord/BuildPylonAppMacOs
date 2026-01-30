# Build Pylon App (macOS)

Pylon is only a web app. It has no app for MacOs.

This script uses [Pake](https://github.com/tw93/Pake) to build a macOS app for [Pylon](https://app.usepylon.com).

![Pylon app screenshot](Screenshot/pylon.png)

## Quick start (one-liner)

From **Terminal** on macOS, run:

```bash
curl -fsSL https://raw.githubusercontent.com/Ogglord/BuildPylonAppMacOs/main/build.sh | bash
```

## What the script does

1. Checks you’re on macOS.
2. Installs [Homebrew](https://brew.sh) if missing.
3. Installs Git and Node.js (LTS) via Homebrew.
4. Installs [Pake](https://github.com/tw93/Pake) (pake-cli) globally.
6. Builds the Pylon app and puts the installer onto your Desktop

If macOS blocks the app (Gatekeeper), right-click the app → **Open** once.

### Security note

Piping from the internet into `bash` runs whatever that URL serves. Only use this one-liner if you trust the source (this repo). To inspect first, download without running:

```bash
curl -fsSL https://raw.githubusercontent.com/Ogglord/BuildPylonAppMacOs/main/build.sh -o build.sh
cat build.sh   # review, then:
bash build.sh
```
