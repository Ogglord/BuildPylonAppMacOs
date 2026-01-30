#!/usr/bin/env bash
set -euo pipefail

# One-shot installer + builder for a Pake macOS app

APP_URL="https://app.usepylon.com"
APP_NAME="Pylon"
ICON_PATH="./PylonIcon.icns"

log() { printf "\n\033[1m%s\033[0m\n" "$*"; }
warn() { printf "\n\033[33m%s\033[0m\n" "$*"; }
err() { printf "\n\033[31m%s\033[0m\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    err "This script is for macOS only."
    exit 1
  fi
}

install_homebrew() {
  if need_cmd brew; then
    log "Homebrew already installed."
    return
  fi

  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for this session (works for Apple Silicon + Intel)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  if ! need_cmd brew; then
    err "Homebrew installation completed but brew isn't on PATH. Open a new terminal and rerun."
    exit 1
  fi
}

install_prereqs() {
  log "Installing prerequisites (Git, Node.js LTS)..."
  brew update >/dev/null
  brew install git node >/dev/null

  log "Checking versions:"
  git --version
  node --version
  npm --version
}

install_pake() {
  # Pake is typically used via npm package "pake-cli"
  if need_cmd pake; then
    log "Pake already installed: $(pake --version 2>/dev/null || echo 'version unknown')"
    return
  fi

  log "Installing Pake (pake-cli) globally with npm..."
  # Make global installs smoother on macOS; fallback if permission issues.
  if npm install -g pake-cli >/dev/null 2>&1; then
    :
  else
    warn "Global install failed (likely permissions). Trying with sudo..."
    sudo npm install -g pake-cli
  fi

  if ! need_cmd pake; then
    err "Installed pake-cli but 'pake' isn't available on PATH."
    err "Try opening a new terminal, or run: npm bin -g"
    exit 1
  fi

  log "Pake installed: $(pake --version 2>/dev/null || echo 'version unknown')"
}

ensure_icon() {
  if [[ -f "$ICON_PATH" ]]; then
    log "Found icon: $ICON_PATH"
    return
  fi

  warn "Icon not found at: $ICON_PATH"
  echo "You have three options:"
  echo "  1) Place PylonIcon.icns in the current directory"
  echo "  2) Enter a different path to an .icns file"
  echo "  3) Continue WITHOUT an icon (uses default)"
  echo

  read -r -p "Choose (1/2/3): " choice
  case "${choice:-}" in
    1)
      if [[ -f "$ICON_PATH" ]]; then
        log "Great — icon found now."
      else
        err "Still not found. Put it here: $(pwd)/PylonIcon.icns and rerun, or choose option 2/3."
        exit 1
      fi
      ;;
    2)
      read -r -p "Enter path to .icns: " user_icon
      if [[ -n "${user_icon:-}" && -f "$user_icon" ]]; then
        ICON_PATH="$user_icon"
        log "Using icon: $ICON_PATH"
      else
        err "That file doesn't exist."
        exit 1
      fi
      ;;
    3)
      ICON_PATH=""
      warn "Continuing without a custom icon."
      ;;
    *)
      err "Invalid choice."
      exit 1
      ;;
  esac
}

choose_output_dir() {
  local default_out="$HOME/Desktop"
  echo
  read -r -p "Output directory for the built app? [default: $default_out] " outdir
  OUT_DIR="${outdir:-$default_out}"
  mkdir -p "$OUT_DIR"
  log "Output directory: $OUT_DIR"
}

build_app() {
  log "Building app with Pake..."

  local cmd=(pake "$APP_URL" --name "$APP_NAME")
  if [[ -n "${ICON_PATH:-}" ]]; then
    cmd+=(--icon "$ICON_PATH")
  fi

  echo
  echo "Running:"
  printf "  %q " "${cmd[@]}"
  echo
  echo

  # Build in a temp dir, then move the resulting .app to OUT_DIR
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  pushd "$tmpdir" >/dev/null
  "${cmd[@]}"
  popd >/dev/null

  # Find the generated .app
  local built_app
  built_app="$(find "$tmpdir" -maxdepth 3 -type d -name "*.app" -print -quit || true)"

  if [[ -z "${built_app:-}" ]]; then
    err "Build finished but no .app was found. Pake output may differ by version."
    err "Check the logs above for the output path."
    exit 1
  fi

  local dest="$OUT_DIR/$(basename "$built_app")"
  rm -rf "$dest"
  mv "$built_app" "$dest"

  log "✅ App created:"
  echo "  $dest"
  echo
  echo "Tip: If macOS blocks it (Gatekeeper), right-click the app → Open."
}

main() {
  require_macos

  log "Pake one-shot setup for: $APP_URL"
  echo "This will install Homebrew, Node.js, and Pake if missing, then build '$APP_NAME'."
  echo
  read -r -p "Continue? [Y/n] " ok
  if [[ "${ok:-Y}" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
  fi

  install_homebrew
  install_prereqs
  install_pake
  ensure_icon
  choose_output_dir
  build_app
}

main "$@"
