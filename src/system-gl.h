#pragma once

#ifndef NULLGL
#ifdef _WIN32
// GL/gl.h and GL/glu.h need APIENTRY/WINGDIAPI from the Windows headers; GLEW >= 2.3
// no longer leaves its own fallback definitions behind after glew.h is processed.
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#  undef DIFFERENCE  // winuser.h macro; clashes with OpenSCADOperator::DIFFERENCE
#endif
#include <GL/glew.h>

#ifdef __APPLE__
 #include <OpenGL/OpenGL.h>
#else
 #include <GL/gl.h>
 #include <GL/glu.h>
#endif

#else // NULLGL
#define GLint int
#define GLuint unsigned int
inline void glColor4fv( float *c ) {}
#endif // NULLGL

#include <string>

std::string glew_dump();
std::string glew_extensions_dump();
bool report_glerror(const char * function);
