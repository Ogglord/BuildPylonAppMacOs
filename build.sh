#!/usr/bin/env bash
set -euo pipefail

# One-shot installer + builder for a Pake macOS app
# Homebrew is run non-interactively (cannot prompt for password in pipe / -c context)
export NONINTERACTIVE=1

APP_URL="https://app.usepylon.com"
APP_NAME="Pylon"
# Pake accepts a URL for --icon (e.g. https://cdn.tw93.fun/pake/weekly.icns)
ICON_URL="https://raw.githubusercontent.com/Ogglord/BuildPylonAppMacOs/main/PylonIcon.icns"

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

load_brew_path() {
  # Put Homebrew on PATH for this session if it's installed but not in PATH (e.g. new terminal)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_homebrew() {
  # Load brew into PATH first so we don't re-run just because this shell hasn't sourced profile
  load_brew_path

  if need_cmd brew; then
    log "Homebrew already installed."
    return
  fi

  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  load_brew_path

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

choose_output_dir() {
  local default_out="$(pwd)"
  if [[ ! -t 0 ]]; then
    OUT_DIR="$default_out"
    mkdir -p "$OUT_DIR"
    log "Output directory: $OUT_DIR"
    return
  fi
  echo
  read -r -p "Output directory for the built app? [default: $default_out] " outdir
  OUT_DIR="${outdir:-$default_out}"
  mkdir -p "$OUT_DIR"
  log "Output directory: $OUT_DIR"
}

build_app() {
  log "Building app with Pake..."

  local cmd=(pake "$APP_URL" --name "$APP_NAME")
  cmd+=(--icon "$ICON_URL")

  echo
  echo "Running:"
  printf "  %q " "${cmd[@]}"
  echo
  echo

  pushd "$OUT_DIR" >/dev/null
  "${cmd[@]}"
  popd >/dev/null

  show_success_banner "$OUT_DIR"
}


show_success_banner() {
  local out_dir="${1:-$(pwd)}"
  local G="\033[32m" Z="\033[0m"
  echo
  echo "  App created in: $out_dir"
  echo
  echo "  Drag \"Pylon.app\" to the Applications folder in Finder."
  echo
  echo "  (If macOS blocks it (Gatekeeper), right-click the app → Open.)"
  echo
}

main() {
  require_macos

  if [[ "${1:-}" == "--dry-run" ]]; then
    show_success_banner "$(pwd)"
    exit 0
  fi

  log "Pake one-shot setup for: $APP_URL"
  echo "This script will:"
  echo "  • Install Homebrew (if not installed)"
  echo "  • Install Git and Node.js via Homebrew (if missing)"
  echo "  • Install Pake (pake-cli) globally via npm (if missing)"
  echo "  • Ask for an output directory (default: current directory)"
  echo "  • Build the '$APP_NAME' app and place the .app in that directory"
  echo
  if [[ -t 0 ]]; then
    read -r -p "Press Enter to continue, or any other key + Enter to abort: " confirm
    [[ -n "${confirm:-}" ]] && { echo "Aborted."; exit 0; }
  fi

  log "Checking sudo (you may be prompted for your password once)..."
  sudo -v

  install_homebrew
  install_prereqs
  install_pake
  choose_output_dir
  build_app
}

main "$@"
