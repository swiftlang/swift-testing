//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_IUNKNOWN_H)
#define SWT_IUNKNOWN_H

#if defined(_WIN32)
#include "Defines.h"
#include "Includes.h"

SWT_ASSUME_NONNULL_BEGIN

/// Add a reference to (retain) a COM object.
///
/// This function is provided because `IUnknown::AddRef()` is a virtual member
/// function and cannot be imported directly into Swift. 
SWT_EXTERN ULONG swt_IUnknown_AddRef(IUnknown *object);

/// Release a COM object.
///
/// This function is provided because `IUnknown::Release()` is a virtual member
/// function and cannot be imported directly into Swift. 
SWT_EXTERN ULONG swt_IUnknown_Release(IUnknown *object);

SWT_ASSUME_NONNULL_END
#endif

#endif
