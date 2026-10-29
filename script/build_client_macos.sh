#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DEPS="$ROOT/.deps"
SDK="$(xcrun --show-sdk-path)"
JOBS="${JOBS:-8}"
trap 'echo "Client build failed; see the latest *client*.log / openal*.log in $DEPS" >&2' ERR
# Bootstrap the shared, pinned source dependencies if this is a fresh checkout.
if [[ ! -f "$DEPS/src/lua-5.0.3/lib/liblua.a" || ! -d "$DEPS/src/ryzomcore/.git" ]]; then
  "$ROOT/script/build_server_macos.sh"
fi
[[ "$(git -C "$DEPS/src/ryzomcore" rev-parse HEAD)" == b64a06e76b13a4d1adc12977edfdd744999ce5d4 ]]
git -C "$DEPS/src/ryzomcore" apply --reverse --check "$ROOT/macos/nel-apple-silicon.patch"
if git -C "$DEPS/src/ryzomcore" apply --check "$ROOT/macos/nel-client-input.patch" 2>/dev/null; then
  git -C "$DEPS/src/ryzomcore" apply "$ROOT/macos/nel-client-input.patch"
else
  git -C "$DEPS/src/ryzomcore" apply --reverse --check "$ROOT/macos/nel-client-input.patch"
fi
ARCHIVE="$DEPS/downloads/openal-soft-1.24.3.tar.gz"
if [[ ! -f "$ARCHIVE" ]]; then
  curl -fL --retry 2 https://github.com/kcat/openal-soft/archive/refs/tags/1.24.3.tar.gz -o "$ARCHIVE"
fi
echo "7e1fecdeb45e7f78722b776c5cf30bd33934b961d7fd2a11e0494e064cc631ce  $ARCHIVE" | shasum -a 256 -c -
[[ -d "$DEPS/src/openal-soft-1.24.3" ]] || tar -xzf "$ARCHIVE" -C "$DEPS/src"
cmake -S "$DEPS/src/openal-soft-1.24.3" -B "$DEPS/build-openal" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS/install-openal" \
  -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF \
  -DALSOFT_INSTALL_CONFIG=OFF > "$DEPS/openal-configure.log" 2>&1
cmake --build "$DEPS/build-openal" -j "$JOBS" > "$DEPS/openal-build.log" 2>&1
cmake --install "$DEPS/build-openal" > "$DEPS/openal-install.log" 2>&1
cmake -S "$DEPS/src/ryzomcore" -B "$DEPS/build-nel-client" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS/install" -DCMAKE_PREFIX_PATH=/opt/homebrew \
  -DWITH_RYZOM=OFF -DWITH_NELNS=OFF -DWITH_GUI=OFF -DWITH_WEB=OFF -DWITH_SOUND=ON \
  -DWITH_PACS=OFF -DWITH_GEORGES=ON -DWITH_LIGO=ON -DWITH_LOGIC=OFF \
  -DWITH_DRIVER_OPENGL=ON -DWITH_DRIVER_OPENAL=ON -DWITH_NEL_TOOLS=OFF \
  -DWITH_NEL_SAMPLES=OFF -DWITH_NEL_TESTS=OFF -DWITH_TESTING=OFF -DWITH_STATIC=ON -DWITH_STATIC_DRIVERS=ON \
  -DWITH_PCH=OFF -DWITH_SSE2=OFF -DWITH_SSE3=OFF -DWITH_STATIC_EXTERNAL=OFF -DWITH_STATIC_LIBXML2=OFF \
  -DZLIB_LIBRARY=/opt/homebrew/opt/zlib/lib/libz.dylib -DZLIB_INCLUDE_DIR=/opt/homebrew/opt/zlib/include \
  -DLIBXML2_LIBRARY="$SDK/usr/lib/libxml2.tbd" -DLIBXML2_INCLUDE_DIR="$SDK/usr/include/libxml2" \
  -DCURL_LIBRARY=/opt/homebrew/opt/curl/lib/libcurl.dylib -DCURL_INCLUDE_DIR=/opt/homebrew/opt/curl/include \
  -DIconv_LIBRARY="$SDK/usr/lib/libiconv.tbd" -DIconv_INCLUDE_DIR="$SDK/usr/include" \
  -DOPENAL_LIBRARY="$DEPS/install-openal/lib/libopenal.a" \
  -DOPENAL_INCLUDE_DIR="$DEPS/install-openal/include/AL" > "$DEPS/nel-client-configure.log" 2>&1
cmake --build "$DEPS/build-nel-client" -j "$JOBS" > "$DEPS/nel-client-build.log" 2>&1
cmake -S "$ROOT/macos/client" -B "$ROOT/build-macos-client" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/homebrew > "$DEPS/client-configure.log" 2>&1
cmake --build "$ROOT/build-macos-client" -j "$JOBS" > "$DEPS/client-build.log" 2>&1
python3 "$ROOT/script/package_client_macos.py"
echo "Built: $ROOT/dist/Tux Target.app"
