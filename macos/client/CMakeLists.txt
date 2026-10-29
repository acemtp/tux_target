cmake_minimum_required(VERSION 3.20)
project(TuxTargetClientMac LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")
set(DEPS "${ROOT}/.deps")
set(NEL_LIB "${DEPS}/build-nel-client/lib")
foreach(PACKAGE Threads ZLIB LibXml2 PNG JPEG GIF Freetype CURL)
    find_package(${PACKAGE} REQUIRED)
endforeach()

find_package(OpenAL CONFIG REQUIRED PATHS "${DEPS}/install-openal/lib/cmake/OpenAL" NO_DEFAULT_PATH)
foreach(FRAMEWORK Carbon Cocoa OpenGL)
    find_library(${FRAMEWORK}_FRAMEWORK ${FRAMEWORK} REQUIRED)
endforeach()
find_library(OGG_LIBRARY ogg REQUIRED)
find_library(VORBIS_LIBRARY vorbis REQUIRED)
find_library(VORBISFILE_LIBRARY vorbisfile REQUIRED)
file(GLOB CLIENT_SOURCES CONFIGURE_DEPENDS "${ROOT}/client/src/*.cpp" "${ROOT}/common/*.cpp")
add_executable(tux-target ${CLIENT_SOURCES})
target_compile_definitions(tux-target PRIVATE NL_RELEASE NL_STATIC TUX_MODERN_NEL HAVE_AARCH64 HAVE_ARM
    TUX_TARGET_CONFIG_DIR="${ROOT}/runtime-macos-client/")
target_include_directories(tux-target PRIVATE
    "${ROOT}/client/src" "${ROOT}/common"
    "${DEPS}/src/ryzomcore/nel/include" "${DEPS}/build-nel-client"
    "${DEPS}/src/lua-5.0.3/include")
target_compile_options(tux-target PRIVATE -Wno-deprecated-declarations -Wno-register)
target_link_libraries(tux-target PRIVATE
    "${NEL_LIB}/libnel_drv_opengl.a" "${NEL_LIB}/libnel_drv_openal.a"
    "${NEL_LIB}/libnelsound.a" "${NEL_LIB}/libnelsnd_lowlevel.a"
    "${NEL_LIB}/libnelligo.a" "${NEL_LIB}/libnelgeorges.a"
    "${NEL_LIB}/libnel3d.a" "${NEL_LIB}/libnelnet.a" "${NEL_LIB}/libnelmisc.a"
    "${NEL_LIB}/libnel_sevenzip.a"
    "${DEPS}/src/lua-5.0.3/lib/liblualib.a" "${DEPS}/src/lua-5.0.3/lib/liblua.a"
    Threads::Threads ZLIB::ZLIB LibXml2::LibXml2 PNG::PNG JPEG::JPEG GIF::GIF Freetype::Freetype CURL::libcurl
    "${OGG_LIBRARY}" "${VORBIS_LIBRARY}" "${VORBISFILE_LIBRARY}"
    "${Carbon_FRAMEWORK}" "${Cocoa_FRAMEWORK}" "${OpenGL_FRAMEWORK}" OpenAL::OpenAL)

# Regression check for the Apple Silicon clock conversion, without opening a window.
add_executable(tux-target-clock-check EXCLUDE_FROM_ALL check_clock.cpp "${ROOT}/client/src/time_task.cpp")
add_executable(tux-target-input-check EXCLUDE_FROM_ALL check_input.cpp)
add_executable(tux-target-audio-check EXCLUDE_FROM_ALL check_audio.cpp)
foreach(PROPERTY INCLUDE_DIRECTORIES COMPILE_DEFINITIONS COMPILE_OPTIONS LINK_LIBRARIES)
    get_target_property(CLIENT_${PROPERTY} tux-target ${PROPERTY})
    set_target_properties(tux-target-clock-check PROPERTIES ${PROPERTY} "${CLIENT_${PROPERTY}}")
    set_target_properties(tux-target-input-check PROPERTIES ${PROPERTY} "${CLIENT_${PROPERTY}}")
    set_target_properties(tux-target-audio-check PROPERTIES ${PROPERTY} "${CLIENT_${PROPERTY}}")
endforeach()
