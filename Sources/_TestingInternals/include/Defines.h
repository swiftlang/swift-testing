//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if !defined(SWT_DEFINES_H)
#define SWT_DEFINES_H

#if __has_feature(assume_nonnull)
#define SWT_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define SWT_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#else
#define SWT_ASSUME_NONNULL_BEGIN
#define SWT_ASSUME_NONNULL_END
#endif

#if defined(__cplusplus)
#define SWT_EXTERN extern "C"
#else
#define SWT_EXTERN extern
#endif

#if defined(_WIN32)
#define SWT_IMPORT_FROM_STDLIB SWT_EXTERN __declspec(dllimport)
#else
#define SWT_IMPORT_FROM_STDLIB SWT_EXTERN
#endif

/// An attribute that marks some value as being `Sendable` in Swift.
#if __has_attribute(__swift_attr__)
#define SWT_SENDABLE __attribute__((swift_attr("@Sendable")))
#else
#define SWT_SENDABLE
#endif

/// An attribute that renames a C symbol in Swift.
#if __has_attribute(swift_name)
#define SWT_SWIFT_NAME(name) __attribute__((swift_name(#name)))
#else
#define SWT_SWIFT_NAME(_name)
#endif

#if __has_attribute(enum_extensibility)
#define __SWT_ENUM_ATTR __attribute__((enum_extensibility(open)))
#define __SWT_ENUM_ATTR_CLOSED __attribute__((enum_extensibility(closed)))
#else
#define __SWT_ENUM_ATTR
#define __SWT_ENUM_ATTR_CLOSED
#endif

#if __has_feature(objc_fixed_enum) || __has_extension(cxx_fixed_enum) || \
        __has_extension(cxx_strong_enums)
#define SWT_ENUM(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } _name##_t
#define SWT_CLOSED_ENUM(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } __SWT_ENUM_ATTR_CLOSED _name##_t
#define SWT_OPTIONS(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } __SWT_ENUM_ATTR __SWT_OPTIONS_ATTR _name##_t
#define SWT_CLOSED_OPTIONS(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } __SWT_ENUM_ATTR_CLOSED __SWT_OPTIONS_ATTR _name##_t
#else
/*!
 * There is unfortunately no good way in plain C to have both fixed-type enums
 * and enforcement for clang's enum_extensibility extensions. The primary goal
 * of these macros is to allow you to define an enum and specify its width in a
 * single statement, and for plain C that is accomplished by defining an
 * anonymous enum and then separately typedef'ing the requested type name to the
 * requested underlying integer type. So the type emitted actually has no
 * relationship at all to the enum, and therefore while the compiler could
 * enforce enum extensibility if you used the enum type, it cannot do so if you
 * use the "_t" type resulting from this expression.
 *
 * But we still define a named enum type and decorate it appropriately for you,
 * so if you really want the enum extensibility enforcement, you can use the
 * enum type yourself, i.e. when compiling with a C compiler:
 *
 *     SWT_CLOSED_ENUM(my_type, uint64_t,
 *         FOO,
 *         BAR,
 *         BAZ,
 *     );
 *
 *     my_type_t mt = 98; // legal
 *     enum my_type emt = 98; // illegal
 *
 * But be aware that the underlying enum type's width is subject only to the C
 * language's guarantees -- namely that it will be compatible with int, char,
 * and unsigned char. It is not safe to rely on the size of this type.
 *
 * When compiling in ObjC or C++, both of the above assignments are illegal.
 */
#define __SWT_ENUM_C_FALLBACK(_name, _type, ...) \
	typedef _type _name##_t; enum _name { __VA_ARGS__ }

#define SWT_ENUM(_name, _type, ...) \
	typedef _type _name##_t; enum { __VA_ARGS__ }
#define SWT_CLOSED_ENUM(_name, _type, ...) \
	__SWT_ENUM_C_FALLBACK(_name, _type, ## __VA_ARGS__) \
	__SWT_ENUM_ATTR_CLOSED
#define SWT_OPTIONS(_name, _type, ...) \
	__SWT_ENUM_C_FALLBACK(_name, _type, ## __VA_ARGS__) \
	__SWT_ENUM_ATTR __SWT_OPTIONS_ATTR
#define SWT_CLOSED_OPTIONS(_name, _type, ...) \
	__SWT_ENUM_C_FALLBACK(_name, _type, ## __VA_ARGS__) \
	__SWT_ENUM_ATTR_CLOSED __SWT_OPTIONS_ATTR
#endif // __has_feature(objc_fixed_enum) || __has_extension(cxx_strong_enums)


#endif // SWT_DEFINES_H
