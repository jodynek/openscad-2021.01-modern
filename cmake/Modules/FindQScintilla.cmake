# Finds QScintilla built against the Qt version in use (Qt 6 first, Qt 5 as fallback).
#
# Searches the Qt installation prefix (CMAKE_PREFIX_PATH / QT6_ROOT) and the usual
# system locations. Defines:
#   QSCINTILLA_FOUND, QSCINTILLA_INCLUDE_DIR, QSCINTILLA_LIBRARY, QSCINTILLA_VERSION_STRING,
#   QSCINTILLA_DLL (Windows, when found next to the Qt binaries)
# and the imported target QScintilla::QScintilla.

set(_qsci_hints)
if(TARGET Qt6::Core)
  get_target_property(_qt_core_location Qt6::Core LOCATION)
  get_filename_component(_qt_core_dir "${_qt_core_location}" DIRECTORY)
  list(APPEND _qsci_hints "${_qt_core_dir}/.." "${_qt_core_dir}/../..")
endif()
if(QT6_ROOT)
  list(APPEND _qsci_hints "${QT6_ROOT}")
endif()

find_path(QSCINTILLA_INCLUDE_DIR
  NAMES Qsci/qsciscintilla.h
  HINTS ${_qsci_hints}
  PATH_SUFFIXES include include/qt6 include/qt5 qt6 qt5
                include/${CMAKE_LIBRARY_ARCHITECTURE}/qt6 ${CMAKE_LIBRARY_ARCHITECTURE}/qt6)

find_library(QSCINTILLA_LIBRARY
  NAMES qscintilla2_qt6 qscintilla2_qt5 qscintilla2
  HINTS ${_qsci_hints}
  PATH_SUFFIXES lib lib64 lib/${CMAKE_LIBRARY_ARCHITECTURE})

if(WIN32)
  find_file(QSCINTILLA_DLL
    NAMES qscintilla2_qt6.dll qscintilla2_qt5.dll
    HINTS ${_qsci_hints}
    PATH_SUFFIXES bin lib)
endif()

set(QSCINTILLA_VERSION_STRING "")
if(QSCINTILLA_INCLUDE_DIR AND EXISTS "${QSCINTILLA_INCLUDE_DIR}/Qsci/qsciglobal.h")
  file(STRINGS "${QSCINTILLA_INCLUDE_DIR}/Qsci/qsciglobal.h" _qsci_version_line REGEX "define[ ]+QSCINTILLA_VERSION_STR")
  if(_qsci_version_line)
    string(REGEX REPLACE ".*define[ ]+QSCINTILLA_VERSION_STR[ ]+\"(.*)\".*" "\\1" QSCINTILLA_VERSION_STRING "${_qsci_version_line}")
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(QScintilla
  REQUIRED_VARS QSCINTILLA_LIBRARY QSCINTILLA_INCLUDE_DIR
  VERSION_VAR QSCINTILLA_VERSION_STRING)

if(QScintilla_FOUND AND NOT TARGET QScintilla::QScintilla)
  add_library(QScintilla::QScintilla UNKNOWN IMPORTED)
  set_target_properties(QScintilla::QScintilla PROPERTIES
    IMPORTED_LOCATION "${QSCINTILLA_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${QSCINTILLA_INCLUDE_DIR}")
  if(WIN32)
    # the headers export/import the class symbols only when QSCINTILLA_DLL is defined
    set_property(TARGET QScintilla::QScintilla PROPERTY INTERFACE_COMPILE_DEFINITIONS QSCINTILLA_DLL)
  endif()
endif()

mark_as_advanced(QSCINTILLA_INCLUDE_DIR QSCINTILLA_LIBRARY QSCINTILLA_DLL)
