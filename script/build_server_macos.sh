#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DEPS="$ROOT/.deps"
JOBS="${JOBS:-8}"
SDK="$(xcrun --show-sdk-path)"
NEL_REV=b64a06e76b13a4d1adc12977edfdd744999ce5d4
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || {
  echo 'This build entrypoint targets Apple Silicon macOS.' >&2; exit 1;
}
mkdir -p "$DEPS/downloads" "$DEPS/src" "$DEPS/install"

download() {
  local url="$1" name="$2" hash="$3"
  if [[ ! -f "$DEPS/downloads/$name" ]]; then
    curl -fL --retry 2 "$url" -o "$DEPS/downloads/$name"
  fi
  echo "$hash  $DEPS/downloads/$name" | shasum -a 256 -c -
}
download https://www.lua.org/ftp/lua-5.0.3.tar.gz lua-5.0.3.tar.gz \
  1193a61b0e08acaa6eee0eecf29709179ee49c71baebc59b682a25c3b5a45671
download https://bitbucket.org/odedevs/ode/downloads/ode-0.16.6.tar.gz ode-0.16.6.tar.gz \
  c91a28c6ff2650284784a79c726a380d6afec87ecf7a35c32a6be0c5b74513e8
[[ -d "$DEPS/src/lua-5.0.3" ]] || tar -xzf "$DEPS/downloads/lua-5.0.3.tar.gz" -C "$DEPS/src"
[[ -d "$DEPS/src/ode-0.16.6" ]] || tar -xzf "$DEPS/downloads/ode-0.16.6.tar.gz" -C "$DEPS/src"
if [[ ! -d "$DEPS/src/ryzomcore/.git" ]]; then
  git init "$DEPS/src/ryzomcore"
  git -C "$DEPS/src/ryzomcore" remote add origin https://github.com/ryzom/ryzomcore.git
  git -C "$DEPS/src/ryzomcore" config core.sparseCheckout true
  mkdir -p "$DEPS/src/ryzomcore/.git/info"
  printf '/*\n!/*/\n/nel/\n/CMakeModules/\n/cmake/\n' > "$DEPS/src/ryzomcore/.git/info/sparse-checkout"
  git -C "$DEPS/src/ryzomcore" fetch --depth 1 --filter=blob:none origin "$NEL_REV"
  git -C "$DEPS/src/ryzomcore" checkout --detach FETCH_HEAD
fi
[[ "$(git -C "$DEPS/src/ryzomcore" rev-parse HEAD)" == "$NEL_REV" ]] || {
  echo 'Unexpected NeL revision; refusing to build a different dependency.' >&2; exit 1;
}
if git -C "$DEPS/src/ryzomcore" apply --check "$ROOT/macos/nel-apple-silicon.patch" 2>/dev/null; then
  git -C "$DEPS/src/ryzomcore" apply "$ROOT/macos/nel-apple-silicon.patch"
else
  git -C "$DEPS/src/ryzomcore" apply --reverse --check "$ROOT/macos/nel-apple-silicon.patch"
fi
make -C "$DEPS/src/lua-5.0.3" -j "$JOBS" CC=clang \
  MYCFLAGS='-Wno-error=implicit-function-declaration -Wno-error=int-conversion' > "$DEPS/lua-build.log" 2>&1
cmake -S "$DEPS/src/ode-0.16.6" -B "$DEPS/build-ode" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS/install" \
  -DODE_WITH_DEMOS=OFF -DODE_WITH_TESTS=OFF -DODE_DOUBLE_PRECISION=OFF \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 > "$DEPS/ode-configure.log" 2>&1
cmake --build "$DEPS/build-ode" -j "$JOBS" > "$DEPS/ode-build.log" 2>&1
cmake --install "$DEPS/build-ode" > "$DEPS/ode-install.log" 2>&1
cmake -S "$DEPS/src/ryzomcore" -B "$DEPS/build-nel" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS/install" -DCMAKE_PREFIX_PATH=/opt/homebrew \
  -DWITH_RYZOM=OFF -DWITH_NELNS=OFF -DWITH_GUI=OFF -DWITH_WEB=OFF -DWITH_SOUND=OFF \
  -DWITH_PACS=OFF -DWITH_GEORGES=OFF -DWITH_LIGO=OFF -DWITH_LOGIC=OFF \
  -DWITH_DRIVER_OPENGL=OFF -DWITH_DRIVER_OPENAL=OFF -DWITH_NEL_TOOLS=OFF \
  -DWITH_NEL_SAMPLES=OFF -DWITH_NEL_TESTS=OFF -DWITH_TESTING=OFF -DWITH_STATIC=ON \
  -DWITH_PCH=OFF -DWITH_SSE2=OFF -DWITH_SSE3=OFF -DWITH_STATIC_EXTERNAL=OFF -DWITH_STATIC_LIBXML2=OFF \
  -DZLIB_LIBRARY=/opt/homebrew/opt/zlib/lib/libz.dylib -DZLIB_INCLUDE_DIR=/opt/homebrew/opt/zlib/include \
  -DLIBXML2_LIBRARY="$SDK/usr/lib/libxml2.tbd" -DLIBXML2_INCLUDE_DIR="$SDK/usr/include/libxml2" \
  -DCURL_LIBRARY=/opt/homebrew/opt/curl/lib/libcurl.dylib -DCURL_INCLUDE_DIR=/opt/homebrew/opt/curl/include \
  -DIconv_LIBRARY="$SDK/usr/lib/libiconv.tbd" -DIconv_INCLUDE_DIR="$SDK/usr/include" > "$DEPS/nel-configure.log" 2>&1
cmake --build "$DEPS/build-nel" -j "$JOBS" > "$DEPS/nel-build.log" 2>&1
cmake -S "$ROOT/macos" -B "$ROOT/build-macos-server" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/homebrew > "$DEPS/server-configure.log" 2>&1
cmake --build "$ROOT/build-macos-server" -j "$JOBS" > "$DEPS/server-build.log" 2>&1
echo "Built: $ROOT/build-macos-server/tux-target-srv"
