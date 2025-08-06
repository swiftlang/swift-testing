//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#include "IUnknown.h"

#if defined(_WIN32)
ULONG swt_IUnknown_AddRef(IUnknown *object) {
    return object->AddRef();
}

ULONG swt_IUnknown_Release(IUnknown *object) {
    return object->Release();
}
#endif