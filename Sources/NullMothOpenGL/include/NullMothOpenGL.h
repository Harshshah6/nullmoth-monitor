/// Detects whether macOS offers an accelerated OpenGL renderer.
///
/// The OpenGL framework is deprecated, so the check lives in C where the
/// deprecation attributes can be silenced for this single call.
#ifndef NULLMOTH_OPENGL_H
#define NULLMOTH_OPENGL_H

#include <stdbool.h>

/// Returns true when the system can create an accelerated OpenGL pixel
/// format, which is what Apple's GL-on-Metal layer provides on top of Metal.
bool nmm_has_accelerated_renderer(void);

#endif /* NULLMOTH_OPENGL_H */
