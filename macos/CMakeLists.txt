cmake_minimum_required(VERSION 3.20)
project(TuxTargetServerMac LANGUAGES C CXX)

# Standalone server build: leave the historical client/build system untouched.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(ROOT "${CMAKE_CURRENT_LIST_DIR}/..")
set(DEPS "${ROOT}/.deps")
find_package(Threads REQUIRED)
find_package(ZLIB REQUIRED)
find_package(LibXml2 REQUIRED)
find_package(PNG REQUIRED)
find_package(JPEG REQUIRED)
find_package(GIF REQUIRED)
find_package(Freetype REQUIRED)
find_library(CARBON_FRAMEWORK Carbon REQUIRED)

file(GLOB SERVER_SOURCES CONFIGURE_DEPENDS "${ROOT}/server/src/*.cpp" "${ROOT}/common/*.cpp")
add_executable(tux-target-srv ${SERVER_SOURCES})
target_compile_definitions(tux-target-srv PRIVATE MT_SERVER MTPT_SERVER NL_RELEASE HAVE_AARCH64 HAVE_ARM
    TUX_TARGET_CONFIG_DIR="${ROOT}/server/")
target_include_directories(tux-target-srv PRIVATE
    "${ROOT}/server/src" "${ROOT}/common"
    "${DEPS}/src/ryzomcore/nel/include" "${DEPS}/build-nel"
    "${DEPS}/src/lua-5.0.3/include" "${DEPS}/install/include")
target_compile_options(tux-target-srv PRIVATE -Wno-deprecated-declarations -Wno-register)
target_link_libraries(tux-target-srv PRIVATE
    "${DEPS}/build-nel/lib/libnel3d.a"
    "${DEPS}/build-nel/lib/libnelnet.a"
    "${DEPS}/build-nel/lib/libnelmisc.a"
    "${DEPS}/build-nel/lib/libnel_sevenzip.a"
    "${DEPS}/src/lua-5.0.3/lib/liblualib.a"
    "${DEPS}/src/lua-5.0.3/lib/liblua.a"
    "${DEPS}/install/lib/libode.a"
    Threads::Threads ZLIB::ZLIB LibXml2::LibXml2 PNG::PNG JPEG::JPEG GIF::GIF
    Freetype::Freetype "${CARBON_FRAMEWORK}")
