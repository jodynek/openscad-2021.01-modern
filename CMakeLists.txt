#
# CMake build system for OpenSCAD
#
# Configuration variables
#   -DHEADLESS=<ON|OFF>
#   -DNULLGL=<ON|OFF>
#   -DSNAPSHOT=<ON|OFF>
#   -DEXPERIMENTAL=<ON|OFF>
#
#  TODO
#   find packages for spnav, hidapi


if(APPLE)
  set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9)
endif()
cmake_minimum_required(VERSION 3.5)

if(POLICY CMP0071)
  cmake_policy(SET CMP0071 OLD)
endif()

project(openscad)

option(INFO "Display build configuration info at end of cmake config" ON)
option(EXPERIMENTAL "Enable Experimental Features" OFF)
option(SNAPSHOT "Create dev snapshot, uses nightly icons" OFF)
option(HEADLESS "Build without GUI frontend" OFF)
option(NULLGL "Build without OpenGL, (implies HEADLESS=ON) " OFF)
option(IDPREFIX "Prefix CSG nodes with index # (debugging purposes only, will break node cache)" OFF)
option(PROFILE "Enable compiling with profiling / test coverage instrumentation" OFF)
option(ENABLE_TESTS "Build the regression test tools and register ctest tests (tests/)" ON)

if(PROFILE)
  SET(GCC_COVERAGE_COMPILE_FLAGS "-g -O0 --coverage -fprofile-arcs -ftest-coverage -fprofile-dir=.gcov")
  SET(GCC_COVERAGE_LINK_FLAGS    "--coverage")
  SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${GCC_COVERAGE_COMPILE_FLAGS}")
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${GCC_COVERAGE_COMPILE_FLAGS}")
  SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${GCC_COVERAGE_LINK_FLAGS}")
  # Make sure to override default optimization for Release type
  string(REPLACE "-O3" "-O0" CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_RELEASE})
else()
  # Use same optimization as qmake build for Release
  string(REPLACE "-O3" "-O2" CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_RELEASE})
endif()

if (NULLGL)
  set(HEADLESS ON)
endif()
if(EXPERIMENTAL)
  add_definitions(-DENABLE_EXPERIMENTAL)
endif()
if(IDPREFIX)
  add_definitions(-DIDPREFIX)
endif()

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/objects")
set(AUTOGEN_BUILD_DIR "${CMAKE_BINARY_DIR}/objects")
file(MAKE_DIRECTORY ${AUTOGEN_BUILD_DIR})

# Default to Release build
#if(NOT CMAKE_BUILD_TYPE)
#  message(STATUS "CMAKE_BUILD_TYPE not specified.  Defaulting to 'Release'")
#  message(STATUS "Usage: cmake -DCMAKE_BUILD_TYPE=[Debug|Release|RelWithDebInfo|MinSizeRel] .")
#  set(CMAKE_BUILD_TYPE Release)
#else()
#  message(STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
#endif()

add_compile_options("$<$<CONFIG:DEBUG>:-DDEBUG>")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_definitions(-D_REENTRANT -DUNICODE -D_UNICODE)
# Stack size 8MB; github issue 116
add_definitions(-DSTACKSIZE=8388608)

if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -frounding-math")
  if (WIN32) # gcc bug spams warnings, See issue #2771
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-attributes")
  endif()
endif()

set(BOOST_DIRECTLY_REQUIRED_LIBRARIES program_options)

find_package(PkgConfig)

macro(find_graphics)
  # NULLGL - Allow us to build without OpenGL(TM). run 'cmake .. -DNULLGL=1'
  # Most tests will fail, but it can be used for testing/experiments
  if(NULLGL)
    add_definitions(-DNULLGL)
  else()
    set(OpenGL_GL_PREFERENCE "GLVND")
    find_package(OpenGL REQUIRED QUIET)
    list(APPEND COMMON_LIBRARIES ${OPENGL_LIBRARIES})

    if(MSVC)
      find_package(GLEW CONFIG REQUIRED QUIET)
      message(STATUS "GLEW: Using target GLEW::GLEW")
      list(APPEND COMMON_LIBRARIES GLEW::GLEW)

      # vcpkg opencsg: 1.4.x installed include/opencsg/opencsg.h, 1.8.x installs include/opencsg.h
      find_path(OPENCSG_INCLUDE_DIR NAMES opencsg.h PATH_SUFFIXES opencsg)
      if(NOT OPENCSG_INCLUDE_DIR)
        message(FATAL_ERROR "opencsg.h not found")
      endif()
      include_directories("${OPENCSG_INCLUDE_DIR}")
    else()
      find_package(GLEW REQUIRED)
      message(STATUS "GLEW_INCLUDE_DIR: ${GLEW_INCLUDE_DIR}")
      message(STATUS "GLEW_LIBRARY: ${GLEW_LIBRARY}")
      include_directories("${GLEW_INCLUDE_DIR}")
      list(APPEND COMMON_LIBRARIES ${GLEW_LIBRARY})

      find_path(OPENCSG_INCLUDE_DIRS opencsg.h)
      include_directories("${OPENCSG_INCLUDE_DIRS}")
    endif()
    find_library(OPENCSG_LIBRARY opencsg)
    list(APPEND COMMON_LIBRARIES ${OPENCSG_LIBRARY})

    message(STATUS "OpenCSG: ${OPENCSG_VERSION_STRING}")
    add_definitions(-DENABLE_OPENCSG)
  endif()
endmacro(find_graphics)

# NOTE FindCGAL.cmake resets the BOOST_* and Boost_* variables,
#   because it looks for Boost itself, so it has to be called
#   before we look for our own required boost libraries.
set(CGAL_DO_NOT_WARN_ABOUT_CMAKE_BUILD_TYPE TRUE)
find_package(CGAL REQUIRED)
message(STATUS "CGAL: ${CGAL_MAJOR_VERSION}.${CGAL_MINOR_VERSION}")
add_definitions(-DENABLE_CGAL)
if(TARGET CGAL::CGAL)
  list(APPEND COMMON_LIBRARIES CGAL::CGAL)
  message(STATUS "CGAL: Using target CGAL::CGAL")
else()
  list(APPEND COMMON_LIBRARIES ${CGAL_LIBRARY})
  list(APPEND COMMON_LIBRARIES ${GMP_LIBRARIES})
  list(APPEND COMMON_LIBRARIES ${MPFR_LIBRARIES})
endif()
# revert any changes to module path from CGAL_Macros.cmake
if (CGAL_MODULE_PATH_IS_SET)
  set(CMAKE_MODULE_PATH ORIGINAL_CMAKE_MODULE_PATH)
endif()


if (MSVC)
  # Flex lexer options
  set(OPENSCAD_FLEX_FLAGS --wincompat --nounistd)
  add_definitions(-D_USE_MATH_DEFINES)

  message("COMMON_LIBRARIES ${COMMON_LIBRARIES}")
  find_package(Eigen3 CONFIG REQUIRED)
  list(APPEND COMMON_LIBRARIES Eigen3::Eigen)

  # vcpkg x64-windows ships Boost as DLLs; static variant is not installed.
  set(Boost_USE_STATIC_LIBS FALSE)
  # CONFIG: use BoostConfig.cmake (Boost >= 1.70 / vcpkg boost-cmake); CMake's FindBoost module is deprecated
  find_package(Boost 1.36 REQUIRED CONFIG COMPONENTS ${BOOST_DIRECTLY_REQUIRED_LIBRARIES})
  message(STATUS "Boost: ${Boost_MAJOR_VERSION}.${Boost_MINOR_VERSION}.${Boost_SUBMINOR_VERSION}")
  message("BOOST DIRS ${Boost_INCLUDE_DIRS}")
  include_directories(${Boost_INCLUDE_DIRS})
  list(APPEND COMMON_LIBRARIES ${Boost_LIBRARIES})

  find_package(harfbuzz CONFIG REQUIRED)
  find_path(HARFBUZZ_INCLUDE_DIRS harfbuzz)
  include_directories(${HARFBUZZ_INCLUDE_DIRS}/harfbuzz)
  list(APPEND COMMON_LIBRARIES harfbuzz::harfbuzz)

  # vcpkg fontconfig no longer provides unofficial-fontconfig; use CMake's FindFontconfig (3.14+)
  find_package(Fontconfig REQUIRED)
  message(STATUS "Fontconfig: ${Fontconfig_VERSION}")
  list(APPEND COMMON_LIBRARIES Fontconfig::Fontconfig)


  find_package(double-conversion CONFIG REQUIRED)
  list(APPEND COMMON_LIBRARIES double-conversion::double-conversion)

  # libintl via CMake's FindIntl (vcpkg port gettext-libintl, or the system libc on Linux)
  find_package(Intl REQUIRED)
  message(STATUS "libintl: ${Intl_LIBRARIES}")
  list(APPEND COMMON_LIBRARIES Intl::Intl)

  # call before setting local CMAKE_MODULE_PATH so we use VCPKG version of FindGLEW
  find_graphics()

  # needed for Qt5QScintilla, maybe others
  set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")

else()
  set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")
  set(CMAKE_PREFIX_PATH "$ENV{OPENSCAD_LIBRARIES}")

  find_package(Eigen3 QUIET)
  if (NOT Eigen3_FOUND)
    # Ubuntu Trusty Eigen package installs FindEigen3.cmake but assumes cmake-2.8, not cmake3
    # See https://packages.ubuntu.com/trusty/all/libeigen3-dev/filelist
    list(APPEND CMAKE_MODULE_PATH "/usr/share/cmake-2.8/Modules")
    find_package(Eigen3 REQUIRED QUIET)
    list(REMOVE_ITEM CMAKE_MODULE_PATH "/usr/share/cmake-2.8/Modules")
  endif()
  if (EIGEN3_VERSION)
    message(STATUS "Eigen3: ${EIGEN3_VERSION}")
  else()
    message(STATUS "Eigen3: ${EIGEN3_VERSION_STRING}")
  endif()
  include_directories(${EIGEN3_INCLUDE_DIR})
  add_definitions(-DEIGEN_DONT_ALIGN)

  find_package(Boost 1.36 REQUIRED COMPONENTS ${BOOST_DIRECTLY_REQUIRED_LIBRARIES})
  message(STATUS "Boost: ${Boost_MAJOR_VERSION}.${Boost_MINOR_VERSION}.${Boost_SUBMINOR_VERSION}")
  include_directories(${Boost_INCLUDE_DIRS})
  list(APPEND COMMON_LIBRARIES ${Boost_LIBRARIES})

  find_package(HarfBuzz 0.9.19 REQUIRED QUIET)
  message(STATUS "Harfbuzz: ${HARFBUZZ_VERSION}")
  include_directories(${HARFBUZZ_INCLUDE_DIRS})
  list(APPEND COMMON_LIBRARIES ${HARFBUZZ_LIBRARIES})

  find_package(FontConfig 2.8.0 REQUIRED QUIET)
  message(STATUS "Fontconfig: ${FONTCONFIG_VERSION}")
  list(APPEND COMMON_LIBRARIES ${FONTCONFIG_LIBRARIES})


  list(APPEND COMMON_LIBRARIES double-conversion)

  find_graphics()
endif()

find_package(LibZip REQUIRED QUIET)
include_directories(${LIBZIP_INCLUDE_DIR_ZIP})
include_directories(${LIBZIP_INCLUDE_DIR_ZIPCONF})
list(APPEND COMMON_LIBRARIES ${LIBZIP_LIBRARY})
add_definitions(-DENABLE_LIBZIP)

find_package(Freetype 2.4.9 REQUIRED QUIET)
message(STATUS "Freetype: ${FREETYPE_VERSION_STRING}")
include_directories(${FREETYPE_INCLUDE_DIRS})
list(APPEND COMMON_LIBRARIES ${FREETYPE_LIBRARIES})

# no version constraint: vcpkg's libxml2 config declares ExactVersion compatibility
find_package(LibXml2 REQUIRED QUIET)
message(STATUS "LibXml2: ${LIBXML2_VERSION_STRING}")
include_directories(${LIBXML2_INCLUDE_DIR})
list(APPEND COMMON_LIBRARIES ${LIBXML2_LIBRARIES})

find_package(Cairo 1.14 QUIET)
if (CAIRO_VERSION)
  message(STATUS "Cairo: ${CAIRO_VERSION}")
  include_directories(${CAIRO_INCLUDE_DIRS})
  list(APPEND COMMON_LIBRARIES ${CAIRO_LIBRARIES})
  add_definitions(-DENABLE_CAIRO)
else()
  message(STATUS "Cairo: disabled")
endif()

find_package(FLEX REQUIRED QUIET)
message(STATUS "Flex: ${FLEX_VERSION}")

find_package(BISON REQUIRED QUIET)
message(STATUS "Bison: ${BISON_VERSION}")

if(NOT MSVC)
  # 3MF import/export through lib3mf when the development package is installed (optional)
  find_package(Lib3MF QUIET)
  if(LIB3MF_FOUND OR LIB3MF_LIBRARIES)
    message(STATUS "Lib3MF: ${LIB3MF_VERSION} (3MF import/export enabled)")
    add_definitions(${LIB3MF_CFLAGS})
    include_directories(${LIB3MF_INCLUDE_DIRS})
    list(APPEND COMMON_LIBRARIES ${LIB3MF_LIBRARIES})
  else()
    message(STATUS "Lib3MF: not found (3MF import/export disabled)")
  endif()
endif()

# Output compilation database (compile_commands.json), so we can e.g. run clang-tidy or other tools separately
set(CMAKE_EXPORT_COMPILE_COMMANDS "ON")
# Use clang-tidy if run with -DCLANG_TIDY=1
find_program(CLANG_TIDY_EXE NAMES clang-tidy)
set(CLANG_TIDY ${CLANG_TIDY} CACHE BOOL "Enable clang-tidy")
if(CLANG_TIDY AND CLANG_TIDY_EXE)
  include(RegexUtils)
  escape_string_as_regex(regex "${CMAKE_SOURCE_DIR}/src")
  set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_EXE};-header-filter=${regex}")
endif()

set(CMAKE_INCLUDE_CURRENT_DIR ON)
include_directories(src)

# Scanner/parser generation.
# Explicit custom commands instead of FLEX_TARGET/BISON_TARGET so we can put them in a
# Ninja job pool of size 1: winflexbison (win_flex/win_bison) uses fixed temp file names
# in %TEMP% (~1_flex_N), and concurrent invocations clobber each other.
set_property(GLOBAL APPEND PROPERTY JOB_POOLS flexbison=1)
set(OPENSCAD_GEN_DIR ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})

function(openscad_add_bison NAME INPUT PREFIX OUTVAR)
  set(out_cxx ${OPENSCAD_GEN_DIR}/${NAME}.cxx)
  set(out_hxx ${OPENSCAD_GEN_DIR}/${NAME}.hxx)
  add_custom_command(OUTPUT ${out_cxx} ${out_hxx}
    COMMAND ${BISON_EXECUTABLE} -d -p ${PREFIX} --defines=${out_hxx} -o ${out_cxx} ${CMAKE_CURRENT_SOURCE_DIR}/${INPUT}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${INPUT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    JOB_POOL flexbison
    COMMENT "[BISON] ${NAME}"
    VERBATIM)
  set(${OUTVAR} ${out_cxx} ${out_hxx} PARENT_SCOPE)
endfunction()

function(openscad_add_flex NAME INPUT OUTVAR)
  set(out_cxx ${OPENSCAD_GEN_DIR}/${NAME}.cxx)
  set(out_hxx ${OPENSCAD_GEN_DIR}/${NAME}.hxx)
  add_custom_command(OUTPUT ${out_cxx} ${out_hxx}
    COMMAND ${FLEX_EXECUTABLE} ${OPENSCAD_FLEX_FLAGS} --header-file=${out_hxx} -o${out_cxx} ${CMAKE_CURRENT_SOURCE_DIR}/${INPUT}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${INPUT} ${ARGN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    JOB_POOL flexbison
    COMMENT "[FLEX] ${NAME}"
    VERBATIM)
  set(${OUTVAR} ${out_cxx} ${out_hxx} PARENT_SCOPE)
endfunction()

openscad_add_bison(parser src/parser.y parser BISON_openscad_parser_OUTPUTS)
openscad_add_flex(lexer src/lexer.l FLEX_openscad_lexer_OUTPUTS ${OPENSCAD_GEN_DIR}/parser.hxx)
openscad_add_bison(comment_parser src/comment_parser.y comment_parser BISON_comment_parser_OUTPUTS)
openscad_add_flex(comment_lexer src/comment_lexer.l FLEX_comment_lexer_OUTPUTS ${OPENSCAD_GEN_DIR}/comment_parser.hxx)

if(NOT HEADLESS)
  # GUI: Qt 6 from the Qt online installer (CMAKE_PREFIX_PATH / QT6_ROOT points at <Qt>/6.x.y/<kit>)
  set(CMAKE_AUTOMOC ON)
  set(CMAKE_AUTOUIC ON)
  set(CMAKE_AUTORCC ON)
  set(CMAKE_INCLUDE_CURRENT_DIR ON)
  if(QT6_ROOT)
    list(APPEND CMAKE_PREFIX_PATH "${QT6_ROOT}")
  endif()
  find_package(Qt6 6.4 COMPONENTS Core Gui Widgets OpenGL OpenGLWidgets Concurrent Network Multimedia REQUIRED)
  message(STATUS "Qt6: ${Qt6_VERSION}")
  add_definitions(-DUSE_QOPENGLWIDGET)

  find_package(QScintilla 2.11 REQUIRED)   # cmake/Modules/FindQScintilla.cmake
  message(STATUS "QScintilla: ${QSCINTILLA_VERSION_STRING}")
  add_definitions(-DUSE_SCINTILLA_EDITOR)
  add_definitions(-DENABLE_MDI)

  if(UNIX AND NOT APPLE)
    find_package(Qt6 COMPONENTS DBus QUIET)
    if(Qt6DBus_FOUND)
      message(STATUS "DBus input driver enabled")
      add_definitions(-DENABLE_DBUS)
      set(INPUT_DRIVER_DBUS_SOURCES src/input/DBusInputDriver.cc)
      qt_add_dbus_interface(INPUT_DRIVER_DBUS_SOURCES org.openscad.OpenSCAD.xml openscad_interface)
      qt_add_dbus_adaptor(INPUT_DRIVER_DBUS_SOURCES org.openscad.OpenSCAD.xml input/DBusInputDriver.h DBusInputDriver openscad_adaptor)
    else()
      message(STATUS "DBus input driver disabled as the QtDBus module could not be found.")
    endif()
  endif()
  # Qt Gamepad does not exist in Qt 6; the QGamepad input driver is not built.
endif()


# Setup ccache (if available) to speed up recompiles. It's especially useful
# when switching back and forth between branches where large numbers of files
# would otherwise need to be re-compiled each time.
find_program(CCACHE_PATH ccache)
if (CCACHE_PATH)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PATH})
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PATH})
endif()

#
# Version
#
set(OPENSCAD_VERSION "" CACHE STRING "Version shown by the program (e.g. 2021.01); empty = build date")
if(OPENSCAD_VERSION)
  set(VERSION ${OPENSCAD_VERSION})
else()
  string(TIMESTAMP VERSION "%Y.%m.%d")
endif()
string(REPLACE "-" ";" SPLITVERSION ${VERSION})
list(GET SPLITVERSION 0 OPENSCAD_SHORTVERSION)
string(REGEX MATCHALL "^[0-9]+|[0-9]+|[0-9]+$" VERSIONLIST "${OPENSCAD_SHORTVERSION}")
list(GET VERSIONLIST 0 OPENSCAD_YEAR)
list(GET VERSIONLIST 1 OPENSCAD_MONTH)
math(EXPR OPENSCAD_MONTH ${OPENSCAD_MONTH}) # get rid of leading zero
list(LENGTH VERSIONLIST VERSIONLEN)
if (${VERSIONLEN} EQUAL 3)
  list(GET VERSIONLIST 2 OPENSCAD_DAY)
  math(EXPR OPENSCAD_DAY ${OPENSCAD_DAY}) # get rid of leading zero
endif()

add_definitions(-DOPENSCAD_VERSION=${VERSION} -DOPENSCAD_SHORTVERSION=${OPENSCAD_SHORTVERSION} -DOPENSCAD_YEAR=${OPENSCAD_YEAR} -DOPENSCAD_MONTH=${OPENSCAD_MONTH})
if (DEFINED OPENSCAD_DAY)
  add_definitions(-DOPENSCAD_DAY=${OPENSCAD_DAY})
endif()
if(DEFINED OPENSCAD_COMMIT)
  add_definitions(-DOPENSCAD_COMMIT=${OPENSCAD_COMMIT})
endif()

#
# Platform specific settings
#
if(APPLE)
  message(STATUS "Offscreen OpenGL Context - using Apple CGL")
  set(PLATFORM_SOURCES src/PlatformUtils-mac.mm src/imageutils-macosx.cc src/CocoaUtils.mm)
  if(NOT HEADLESS)
    set(PLATFORM_SOURCES ${PLATFORM_SOURCES} src/AppleEvents.cc)
  endif()
  if(NULLGL)
    add_definitions(-DOPENSCAD_OS="Mac OS X")
  else()
    set(PLATFORM_SOURCES ${PLATFORM_SOURCES} src/OffscreenContextCGL.mm)
  endif()
  find_library(COCOA_LIBRARY Cocoa)
  set(PLATFORM_LIBS ${COCOA_LIBRARY})
elseif(UNIX)
  message(STATUS "Offscreen OpenGL Context - using Unix GLX on X11")
  set(PLATFORM_SOURCES src/imageutils-lodepng.cc src/PlatformUtils-posix.cc)
  if(NULLGL)
    add_definitions(-DOPENSCAD_OS="Unix")
  else()
    set(PLATFORM_SOURCES ${PLATFORM_SOURCES} src/OffscreenContextGLX.cc)
    find_library(X11_LIBRARY X11)
    set(PLATFORM_LIBS ${X11_LIBRARY})
  endif()
elseif(WIN32)
  add_definitions(-DNOGDI)
  message(STATUS "Offscreen OpenGL Context - using Microsoft WGL")
  set(PLATFORM_SOURCES src/imageutils-lodepng.cc src/PlatformUtils-win.cc)
  if(NULLGL)
    add_definitions(-DOPENSCAD_OS="Windows")
  else()
    set(PLATFORM_SOURCES ${PLATFORM_SOURCES} src/OffscreenContextWGL.cc)
  endif()
endif()

include_directories("src/ext/libtess2/Include")

# NOTE: To keep HEADLESS builds working, do NOT add Qt-dependent sources here,
#       see GUI_SOURCES list below for that.
set(CORE_SOURCES
  src/annotation.cc
  src/boost-utils.cc
  src/builtin.cc
  src/builtincontext.cc
  src/calc.cc
  src/cgaladv.cc
  src/clipper-utils.cc
  src/color.cc
  src/colormap.cc
  src/context.cc
  src/control.cc
  src/comment.cpp
  src/csgnode.cc
  src/csgops.cc
  src/degree_trig.cc
  src/dxfdata.cc
  src/dxfdim.cc
  src/evalcontext.cc
  src/export.cc
  src/export_3mf.cc
  src/export_amf.cc
  src/export_dxf.cc
  src/export_off.cc
  src/export_pdf.cc
  src/export_stl.cc
  src/export_svg.cc
  src/expr.cc
  src/feature.cc
  src/fileutils.cc
  src/func.cc
  src/function.cc
  src/handle_dep.cc
  src/hash.cc
  src/import.cc
  src/import_3mf.cc
  src/import_amf.cc
  src/import_stl.cc
  src/import_off.cc
  src/import_svg.cc
  src/linalg.cc
  src/linearextrude.cc
  src/localscope.cc
  src/modcontext.cc
  src/module.cc
  src/node.cc
  src/nodedumper.cc
  src/offset.cc
  src/parsersettings.cc
  src/polyset.cc
  src/polyset-utils.cc
  src/primitives.cc
  src/printutils.cc
  src/progress.cc
  src/projection.cc
  src/render.cc
  src/rendersettings.cc
  src/rotateextrude.cc
  src/stackcheck.h
  src/surface.cc
  src/svg.cc
  src/text.cc
  src/transform.cc
  src/value.cc
  src/version.cc
  src/Assignment.cc
  src/AST.cc
  src/Camera.cc
  src/CSGTreeNormalizer.cc
  src/DrawingCallback.cc
  src/FileModule.cc
  src/FontCache.cc
  src/FreetypeRenderer.cc
  src/Geometry.cc
  src/GeometryCache.cc
  src/GeometryUtils.cc
  src/GroupModule.cc
  src/LibraryInfo.cc
  src/ModuleInstantiation.cc
  src/ModuleCache.cc
  src/NodeVisitor.cc
  src/PlatformUtils.cc
  src/Polygon2d.cc
  src/RenderStatistic.cc
  src/StatCache.cc
  src/UserModule.cc
  src/Tree.cc
  src/ext/lodepng/lodepng.cpp
  src/ext/polyclipping/clipper.cpp
  src/ext/libtess2/Source/bucketalloc.c
  src/ext/libtess2/Source/dict.c
  src/ext/libtess2/Source/geom.c
  src/ext/libtess2/Source/mesh.c
  src/ext/libtess2/Source/priorityq.c
  src/ext/libtess2/Source/sweep.c
  src/ext/libtess2/Source/tess.c
  src/libsvg/circle.cc
  src/libsvg/data.cc
  src/libsvg/ellipse.cc
  src/libsvg/group.cc
  src/libsvg/libsvg.cc
  src/libsvg/line.cc
  src/libsvg/path.cc
  src/libsvg/polygon.cc
  src/libsvg/polyline.cc
  src/libsvg/rect.cc
  src/libsvg/shape.cc
  src/libsvg/svgpage.cc
  src/libsvg/text.cc
  src/libsvg/transformation.cc
  src/libsvg/tspan.cc
  src/libsvg/util.cc
  src/parameter/parameterset.cpp
  ${PLATFORM_SOURCES}
  ${FLEX_openscad_lexer_OUTPUTS}
  ${BISON_openscad_parser_OUTPUTS}
  ${FLEX_comment_lexer_OUTPUTS}
  ${BISON_comment_parser_OUTPUTS})

set(CGAL_SOURCES
  src/cgalutils.cc
  src/cgalutils-applyops.cc
  src/cgalutils-polyhedron.cc
  src/cgalutils-project.cc
  src/cgalutils-tess.cc
  src/export_nef.cc
  src/import_nef.cc
  src/CGAL_Nef_polyhedron.cc
  src/CGALCache.cc
  src/CSGTreeEvaluator.cc
  src/Polygon2d-CGAL.cc
  src/GeometryEvaluator.cc)

#
# Offscreen OpenGL context source code
#
if(NULLGL)
  message(STATUS "NULLGL is set. Overriding OpenGL(TM) settings")
  set(OFFSCREEN_SOURCES
    src/export_png.cc
    src/imageutils.cc
    src/renderer.cc
    src/render.cc
    src/NULLGL.cc # contains several 'nullified' versions of above .cc files
    src/OffscreenView.cc
    src/OffscreenContextNULL.cc
    src/${OFFSCREEN_IMGUTILS_SOURCE})
else()
  set(OFFSCREEN_SOURCES
    src/export_png.cc
    src/fbo.cc
    src/imageutils.cc
    src/render.cc
    src/renderer.cc
    src/system-gl.cc
    src/CGALRenderer.cc
    src/GLView.cc
    src/OffscreenView.cc
    src/OpenCSGRenderer.cc
    src/ThrownTogetherRenderer.cc)
endif()


if(UNIX AND (NOT APPLE) AND (NOT HEADLESS))
  set(PLATFORM_INPUT_DRIVER_SOURCES src/input/JoystickInputDriver.cc)
  add_definitions(-DENABLE_JOYSTICK)
endif()

set(INPUT_DRIVER_SOURCES
  ${PLATFORM_INPUT_DRIVER_SOURCES}
  ${INPUT_DRIVER_DBUS_SOURCES})

set(GUI_SOURCES
  ${GUI_SOURCES}
  src/cgalworker.cc
  src/editor.cc
  src/initConfig.cc
  src/launchingscreen.cc
  src/mainwin.cc
  src/mouseselector.cc
  src/scadapi.cc
  src/scadlexer.cpp
  src/scintillaeditor.cpp
  src/settings.cc
  src/tabmanager.cc
  src/tabwidget.cc
  src/AutoUpdater.cc
  src/Console.cc
  src/Dock.cc
  src/ErrorLog.cc
  src/EventFilter.h
  src/FontListDialog.cc
  src/FontListTableView.cc
  src/LibraryInfoDialog.cc
  src/OctoPrint.cc
  src/OpenCSGWarningDialog.cc
  src/OpenSCADApp.cc
  src/Preferences.cc
  src/PrintInitDialog.cc
  src/PrintService.cc
  src/ProgressWidget.cc
  src/QGLView.cc
  src/QSettingsCached.cc
  src/QWordSearchField.cc
  src/SettingsWriter.cc
  src/UIUtils.cc
  src/WindowManager.cc
  src/parameter/groupwidget.cpp
  src/parameter/ignoreWheelWhenNotFocused.cpp
  src/parameter/parametercheckbox.cpp
  src/parameter/parametercombobox.cpp
  src/parameter/parameterextractor.cpp
  src/parameter/parameterobject.cpp
  src/parameter/parameterslider.cpp
  src/parameter/parameterspinbox.cpp
  src/parameter/parametertext.cpp
  src/parameter/parametervector.cpp
  src/parameter/parametervirtualwidget.cpp
  src/parameter/ParameterWidget.cc
  src/input/AxisConfigWidget.cc
  src/input/ButtonConfigWidget.cc
  src/input/InputDriver.cc
  src/input/InputDriverManager.cc
  src/input/InputEventMapper.cc
  src/input/WheelIgnorer.cc
  ${INPUT_DRIVER_SOURCES}
  )

# header-only code
set(GUI_HEADERS
  src/AboutDialog.h
  src/MainWindow.h
  src/Network.h
  src/NetworkSignal.h
  )

file(GLOB UIs src/*.ui)
file(GLOB Resources *.qrc)

set(Sources src/openscad.cc ${CORE_SOURCES} ${CGAL_SOURCES} ${OFFSCREEN_SOURCES} ${Resources})
if(HEADLESS)
  add_definitions(-DOPENSCAD_NOGUI)
else()
  list(APPEND Sources ${GUI_SOURCES} ${GUI_HEADERS})
endif()

if (SNAPSHOT)
  add_definitions(-DOPENSCAD_SNAPSHOT)
  set(RESOURCE_FILES icons/icon-nightly.icns)
else()
  set(RESOURCE_FILES icons/OpenSCAD.icns)
endif()

if(ENABLE_SPNAV)
  add_definitions(-DENABLE_SPNAV)
  list(APPEND Sources src/input/SpaceNavInputDriver.cc)
endif()

add_executable(OpenSCAD ${Sources} ${RESOURCE_FILES})

#
# Windows version resource (icon + ProductName/ProductVersion in the exe properties).
# Code signing (SignPath) requires identical ProductName/ProductVersion in every signed binary.
#
if(MSVC)
  set(OPENSCAD_PRODUCT_NAME "OpenSCAD 2021.01 Modern" CACHE STRING "ProductName attribute of the Windows binaries")
  set(OPENSCAD_MODERN_RELEASE "1" CACHE STRING "Release number of the modern build (tag v2021.01-modern.N)")
  set(RC_PRODUCTNAME "${OPENSCAD_PRODUCT_NAME}")
  set(RC_FILEVERSION "${OPENSCAD_YEAR},${OPENSCAD_MONTH},${OPENSCAD_MODERN_RELEASE},0")
  set(RC_FILEVERSION_STR "${OPENSCAD_YEAR}.${OPENSCAD_MONTH}.${OPENSCAD_MODERN_RELEASE}.0")
  set(RC_PRODUCTVERSION_STR "${VERSION}-modern.${OPENSCAD_MODERN_RELEASE}")
  set(RC_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
  if(HEADLESS)
    set(RC_FILEDESCRIPTION "OpenSCAD command-line renderer")
    set(RC_ORIGINALFILENAME "openscad.exe")
  else()
    set(RC_FILEDESCRIPTION "OpenSCAD - The Programmers Solid 3D CAD Modeller")
    set(RC_ORIGINALFILENAME "OpenSCAD.exe")
  endif()
  configure_file("${CMAKE_SOURCE_DIR}/openscad_win32.rc.in" "${CMAKE_BINARY_DIR}/openscad_win32.rc" @ONLY)
  target_sources(OpenSCAD PRIVATE "${CMAKE_BINARY_DIR}/openscad_win32.rc")
endif()

# Resource folders the program looks up next to the executable (PlatformUtils::lookupResourcesPath):
# copy them into the build output so a build tree is self-contained (and looks like a release layout).
set(OPENSCAD_RESOURCE_DIRS color-schemes examples fonts libraries templates)
foreach(_res ${OPENSCAD_RESOURCE_DIRS})
  add_custom_command(TARGET OpenSCAD POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_SOURCE_DIR}/${_res}" "$<TARGET_FILE_DIR:OpenSCAD>/${_res}"
    COMMENT "copying resource folder ${_res}")
endforeach()
if(WIN32)
  # fontconfig has no system configuration on Windows; FontCache uses fonts/fonts.conf when present
  add_custom_command(TARGET OpenSCAD POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_SOURCE_DIR}/fonts/fonts.conf.windows" "$<TARGET_FILE_DIR:OpenSCAD>/fonts/fonts.conf"
    COMMENT "installing fonts/fonts.conf for Windows")
endif()

if(APPLE)
  set_target_properties(OpenSCAD PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/Info.plist.in
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_ICON_FILE OpenSCAD.icns
    MACOSX_BUNDLE_BUNDLE_VERSION 2017.03
    MACOSX_BUNDLE_SHORT_VERSION_STRING 2017.03
    RESOURCE "${RESOURCE_FILES}"
  )
elseif(UNIX)
  set_target_properties(OpenSCAD PROPERTIES
    OUTPUT_NAME openscad
  )
elseif(MSVC)
  if(HEADLESS)
    # command-line tool: console subsystem so output is visible in cmd/PowerShell
    set_target_properties(OpenSCAD PROPERTIES
      OUTPUT_NAME openscad
      LINK_FLAGS "-subsystem:console -stack:8388608"
    )
  else()
    set_target_properties(OpenSCAD PROPERTIES
      LINK_FLAGS "-subsystem:windows -ENTRY:mainCRTStartup -stack:8388608"
    )
  endif()
endif()

if(ENABLE_SPNAV)
  target_link_libraries(OpenSCAD spnav)
endif()

target_link_libraries(OpenSCAD PRIVATE ${COMMON_LIBRARIES} ${PLATFORM_LIBS})
# std::filesystem lives in a separate library on GCC < 9
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9)
  target_link_libraries(OpenSCAD PRIVATE stdc++fs)
endif()
if(NOT HEADLESS)
  target_link_libraries(OpenSCAD PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::OpenGL Qt6::OpenGLWidgets Qt6::Concurrent Qt6::Network Qt6::Multimedia QScintilla::QScintilla)
  if(Qt6DBus_FOUND)
    target_link_libraries(OpenSCAD PRIVATE Qt6::DBus)
  endif()
  if(WIN32)
    # copy the Qt runtime (DLLs, platform plugin, ...) and the QScintilla DLL next to the executable
    get_target_property(_qmake_location Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(_qt_bin_dir "${_qmake_location}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE NAMES windeployqt HINTS "${_qt_bin_dir}")
    set(_deploy_binaries "$<TARGET_FILE:OpenSCAD>")
    if(QSCINTILLA_DLL)
      # the QScintilla DLL has Qt dependencies of its own (Qt6PrintSupport), so windeployqt must scan it too
      get_filename_component(_qsci_dll_name "${QSCINTILLA_DLL}" NAME)
      add_custom_command(TARGET OpenSCAD POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${QSCINTILLA_DLL}" "$<TARGET_FILE_DIR:OpenSCAD>"
        COMMENT "copying QScintilla DLL")
      list(APPEND _deploy_binaries "$<TARGET_FILE_DIR:OpenSCAD>/${_qsci_dll_name}")
    endif()
    if(WINDEPLOYQT_EXECUTABLE)
      add_custom_command(TARGET OpenSCAD POST_BUILD
        COMMAND "${WINDEPLOYQT_EXECUTABLE}" --no-translations --no-compiler-runtime --no-opengl-sw ${_deploy_binaries}
        COMMENT "windeployqt: copying the Qt runtime next to $<TARGET_FILE_NAME:OpenSCAD>")
    endif()
  endif()
endif()

if(INFO)
  include(info)
endif()

if(ENABLE_TESTS)
  add_subdirectory(tests)
endif()
