//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals
private import SwiftShims

/// A human-readable string describing the current operating system's version.
///
/// This value's format is platform-specific and is not meant to be
/// machine-readable. It is added to the output of a test run when using
/// an event writer.
///
/// This value is not part of the public interface of the testing library.
let operatingSystemVersion: String = {
#if !SWT_NO_SYSCTL && SWT_TARGET_OS_APPLE
  let productVersion = sysctlbyname("kern.osproductversion", as: String.self) ?? ""
  let buildNumber = sysctlbyname("kern.osversion", as: String.self) ?? ""
  switch (productVersion, buildNumber) {
  case ("", ""):
    break
  case let ("", buildNumber):
    return buildNumber
  case let (productVersion, ""):
    return productVersion
  default:
    return "\(productVersion) (\(buildNumber))"
  }
#elseif !SWT_NO_UNAME && (SWT_TARGET_OS_APPLE || os(Linux) || os(FreeBSD) || os(OpenBSD))
  var name = utsname()
  if 0 == uname(&name) {
    let release = withUnsafeBytes(of: name.release) { release in
      release.withMemoryRebound(to: CChar.self) { release in
        String(validatingCString: release.baseAddress!) ?? ""
      }
    }
    let version = withUnsafeBytes(of: name.version) { version in
      version.withMemoryRebound(to: CChar.self) { version in
        String(validatingCString: version.baseAddress!) ?? ""
      }
    }
    switch (release, version) {
    case ("", ""):
      break
    case let (release, ""):
      return release
    case let ("", version):
      return version
    default:
      return "\(release) (\(version))"
    }
  }
#elseif os(Android)
  if let version = systemProperty(named: "ro.build.version.release") {
    return "Android \(version)"
  }
#elseif os(Windows)
  // See if we can query the kernel directly, bypassing the fake-out logic added
  // in Windows 10 and later that misreports the OS version. GetVersionExW()
  // basically always lies on Windows 10, so don't bother calling it on a
  // fallback path.
  let RtlGetVersion = symbol(in: GetModuleHandleA("ntdll.dll"), named: "RtlGetVersion").map {
    castCFunction(at: $0, to: (@convention(c) (UnsafeMutablePointer<OSVERSIONINFOW>) -> NTSTATUS).self)
  }
  if let RtlGetVersion {
    var versionInfo = OSVERSIONINFOW()
    versionInfo.dwOSVersionInfoSize = .init(MemoryLayout.stride(ofValue: versionInfo))
    if RtlGetVersion(&versionInfo) >= 0 {
      var result = "\(versionInfo.dwMajorVersion).\(versionInfo.dwMinorVersion) Build \(versionInfo.dwBuildNumber)"

      // Include Service Pack details if available.
      if versionInfo.szCSDVersion.0 != 0 {
        withUnsafeBytes(of: versionInfo.szCSDVersion) { szCSDVersion in
          szCSDVersion.withMemoryRebound(to: wchar_t.self) { szCSDVersion in
            if let szCSDVersion = String.decodeCString(szCSDVersion.baseAddress!, as: UTF16.self)?.result {
              result += " (\(szCSDVersion))"
            }
          }
        }
      }

      return result
    }
  }
#elseif os(WASI)
  if let version = swt_getWASIVersion().flatMap(String.init(validatingCString:)) {
    return version
  }
#else
#warning("Platform-specific implementation missing: OS version unavailable")
#endif
  return "unknown"
}()

#if targetEnvironment(simulator)
/// A human-readable string describing the simulated operating system's version.
///
/// This value's format is platform-specific and is not meant to be
/// machine-readable. It is added to the output of a test run when using
/// an event writer.
///
/// This value is not part of the public interface of the testing library.
let simulatorVersion: String = {
  let productVersion = Environment.variable(named: "SIMULATOR_RUNTIME_VERSION") ?? ""
  let buildNumber = Environment.variable(named: "SIMULATOR_RUNTIME_BUILD_VERSION") ?? ""
  switch (productVersion, buildNumber) {
  case ("", ""):
    return "unknown"
  case let ("", buildNumber):
    return buildNumber
  case let (productVersion, ""):
    return productVersion
  default:
    return "\(productVersion) (\(buildNumber))"
  }
}()
#endif

/// A human-readable string describing the testing library's version.
///
/// This value's format is platform-specific and is not meant to be
/// machine-readable. It is added to the output of a test run when using
/// an event writer.
///
/// This value is not part of the public interface of the testing library.
let testingLibraryVersion: String = {
  var result = swt_getTestingLibraryVersion().flatMap(String.init(validatingCString:)) ?? "unknown"

  // Get details of the git commit used when compiling the testing library.
  var commitHash: UnsafePointer<CChar>?
  var commitModified = CBool(false)
  swt_getTestingLibraryCommit(&commitHash, &commitModified)

  if let commitHash = commitHash.flatMap(String.init(validatingCString:)) {
    // Truncate to 15 characters of the hash to match `swift --version`.
    let commitHash = commitHash.prefix(15)
    if commitModified {
      result = "\(result) (\(commitHash) - modified)"
    } else {
      result = "\(result) (\(commitHash))"
    }
  }

  return result
}()

/// Get the LLVM target triple used to build the testing library, if available.
///
/// This value is not part of the public interface of the testing library.
var targetTriple: String? {
  swt_getTargetTriple().flatMap(String.init(validatingCString:))
}

/// A human-readable string describing the Swift Standard Library's version.
///
/// This value is unavailable on some earlier Apple runtime targets. On those
/// targets, this property has a value of `5.0.0`.
///
/// This value is not part of the public interface of the testing library.
let swiftStandardLibraryVersion: VersionNumber? = {
  guard #available(_swiftVersionAPI, *) else {
    return VersionNumber(5, 0)
  }
  let packedValue = _SwiftStdlibVersion.current._value
  return VersionNumber(
    majorComponent: .init((packedValue & 0xFFFF0000) >> 16),
    minorComponent: .init((packedValue & 0x0000FF00) >> 8),
    patchComponent: .init((packedValue & 0x000000FF) >> 0)
  )
}()

/// The version of the Swift compiler used to build the testing library.
///
/// This value is determined at compile time by the Swift compiler. For more
/// information, see [Version.h](https://github.com/swiftlang/swift/blob/main/include/swift/Basic/Version.h)
/// and [ClangImporter.cpp](https://github.com/swiftlang/swift/blob/main/lib/ClangImporter/ClangImporter.cpp)
/// in the Swift repository.
///
/// This value is not part of the public interface of the testing library.
var swiftCompilerVersion: VersionNumber {
  let packedValue = swt_getSwiftCompilerVersion()
  if packedValue == 0, let swiftStandardLibraryVersion {
    // The compiler did not supply its version. This is currently expected on
    // non-Darwin targets in particular. Substitute the stdlib version (which
    // should generally be aligned on non-Darwin targets.)
    return swiftStandardLibraryVersion
  }
  return VersionNumber(
    majorComponent: .init((packedValue % 1_000_000_000_000_000) / 1_000_000_000_000),
    minorComponent: .init((packedValue % 1_000_000_000_000)     / 1_000_000_000),
    patchComponent: .init((packedValue % 1_000_000_000)         / 1_000_000)
  )
}

#if os(Linux) && canImport(Glibc)
/// The (runtime, not compile-time) version of glibc in use on this system.
///
/// This value is not part of the public interface of the testing library.
let glibcVersion: VersionNumber = {
  // Default to the statically available version number if the function call
  // fails for some reason.
  var major = Int(clamping: __GLIBC__)
  var minor = Int(clamping: __GLIBC_MINOR__)

  if let strVersion = gnu_get_libc_version() {
    withUnsafeMutablePointer(to: &major) { major in
      withUnsafeMutablePointer(to: &minor) { minor in
        withVaList([major, minor]) { args in
          _ = vsscanf(strVersion, "%zd.%zd", args)
        }
      }
    }
  }

  return VersionNumber(majorComponent: .init(clamping: major), minorComponent: .init(clamping: minor))
}()
#endif

// MARK: - sysctlbyname() Wrapper

#if !SWT_NO_SYSCTL && SWT_TARGET_OS_APPLE
/// Get a string value by calling `sysctlbyname()`.
///
/// - Parameters:
///   - name: The name of the value to get, such as `"kern.osversion"`.
///
/// - Returns: A string containing the requested value interpreted as a UTF-8
///   string, or `nil` if the value could not be read or could not be
///   interpreted as UTF-8.
///
/// This function is not part of the public interface of the testing library.
func sysctlbyname(_ name: String, as _: String.Type) -> String? {
  name.withCString { name in
    var szValue = 0
    if 0 == sysctlbyname(name, nil, &szValue, nil, 0) {
      return withUnsafeTemporaryAllocation(of: CChar.self, capacity: szValue) { buffer in
        if 0 == sysctlbyname(name, buffer.baseAddress!, &szValue, nil, 0) {
          return String(validatingCString: buffer.baseAddress!)
        }
        return nil
      }
    }
    return nil
  }
}
#endif

#if os(Android)
/// Get the Android system property with the given name.
///
/// - Parameters:
///   - name: The name of the system property to get.
///
/// - Returns: The value of the requested system property, or `nil` if it could
///   not be read or could not be converted to a string.
func systemProperty(named name: String) -> String? {
  withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(PROP_VALUE_MAX)) { buffer in
    let length = __system_property_get(name, buffer.baseAddress!)
    if length > 0 {
      return String(validatingCString: buffer.baseAddress!)
    }
    return nil
  }
}
#endif
