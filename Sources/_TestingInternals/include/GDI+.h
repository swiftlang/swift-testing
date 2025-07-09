//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_GDIPLUS_H)
#define SWT_GDIPLUS_H

#if defined(_WIN32)

#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN
SWT_EXTERN ULONG_PTR swt_gdiplus_startup(int *outError);
SWT_EXTERN void swt_gdiplus_shutdown(ULONG_PTR *token);

SWT_EXTERN void *swt_gdiplus_createImageFromHBITMAP(HBITMAP bitmap, HPALETTE _Nullable palette);
SWT_EXTERN void swt_gdiplus_destroyImage(void *image);

SWT_EXTERN void *_Nullable swt_gdiplus_copyBytes(void *image, const CLSID *clsid, size_t *outByteCount, int *outError);
SWT_ASSUME_NONNULL_END

#endif

#endif // SWT_DEFINES_H
