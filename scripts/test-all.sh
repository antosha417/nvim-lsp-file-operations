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
  *) echo "unsupported platform: $os-$arch" >&2; exit 1 ;;
esac

# Ensure plenary is available
if [ ! -d "$DEPS/plenary.nvim" ]; then
  git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "$DEPS/plenary.nvim"
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
  if ! "$nvim_bin" --headless -u tests/minimal_init.lua \
    -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"; then
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "==> Some Neovim versions FAILED" >&2
  exit 1
fi
echo "==> All Neovim versions passed"
