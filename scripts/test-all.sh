#!/usr/bin/env bash
# Run the test suite against multiple Neovim versions.
# Binaries are downloaded once and cached in .test-deps/.
set -euo pipefail

VERSIONS="${NVIM_VERSIONS:-v0.10.4 stable nightly}"
DEPS=".test-deps"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$os-$arch" in
  darwin-arm64) asset="nvim-macos-arm64" ;;
  darwin-x86_64) asset="nvim-macos-x86_64" ;;
  linux-x86_64) asset="nvim-linux-x86_64" ;;
  linux-aarch64) asset="nvim-linux-arm64" ;;
  *)
    echo "unsupported platform: $os-$arch" >&2
    exit 1
    ;;
esac

if ! command -v busted &> /dev/null; then
  if command -v luarocks &> /dev/null; then
    luarocks install --local nlua
    luarocks install --local busted
  else
    echo "busted is required for testing. Cannot find luarocks to download it!" >&2
    exit 1
  fi
fi

failed=0
for ver in $VERSIONS; do
  nvim_bin="$DEPS/nvim-$ver/bin/nvim"
  if [ ! -x "$nvim_bin" ]; then
    echo "==> Downloading Neovim $ver"
    mkdir -p "$DEPS/nvim-$ver"
    curl -sL "https://github.com/neovim/neovim/releases/download/$ver/$asset.tar.gz" \
    | tar xz -C "$DEPS/nvim-$ver" --strip-components=1
  fi

  echo "==> Testing with $($nvim_bin --version | head -1)"
  ! busted && failed=1
done

if [ "$failed" -ne 0 ]; then
  echo "==> Some Neovim versions FAILED" >&2
  exit 1
fi
echo "==> All Neovim versions passed"
# vim: set ts=2 sts=2 sw=2 et ft=bash:
