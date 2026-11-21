#define GL_SILENCE_DEPRECATION 1

#include "NullMothOpenGL.h"

#include <OpenGL/OpenGL.h>

bool nmm_has_accelerated_renderer(void) {
    CGLPixelFormatAttribute attributes[] = {
        kCGLPFAAccelerated,
        kCGLPFADoubleBuffer,
        kCGLPFAAlphaSize, 8,
        kCGLPFAColorSize, 24,
        kCGLPFADepthSize, 16,
        0,
    };

    CGLPixelFormatObj pixel_format = NULL;
    GLint count = 0;

    /* The whole OpenGL framework is deprecated, but this one call is the
     * only way to ask the system for an accelerated renderer. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGLError error = CGLChoosePixelFormat(attributes, &pixel_format, &count);
#pragma clang diagnostic pop
    return error == kCGLNoError && count > 0;
}
