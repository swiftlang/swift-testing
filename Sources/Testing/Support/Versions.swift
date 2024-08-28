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
#elseif !SWT_NO_UNAME && (SWT_TARGET_OS_APPLE || os(Linux) || os(WASI))
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
#elseif os(Windows)
  // See if we can query the kernel directly, bypassing the fake-out logic added
  // in Windows 10 and later that misreports the OS version. GetVersionExW()
  // basically always lies on Windows 10, so don't bother calling it on a
  // fallback path.
  let RtlGetVersion = symbol(in: GetModuleHandleA("ntdll.dll"), named: "RtlGetVersion").map {
    unsafeBitCast($0, to: (@convention(c) (UnsafeMutablePointer<OSVERSIONINFOW>) -> NTSTATUS).self)
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
  if let libcVersion = swt_getWASIVersion().flatMap(String.init(validatingCString:)), !libcVersion.isEmpty {
    return "WASI with libc \(libcVersion)"
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
var testingLibraryVersion: String {
  swt_getTestingLibraryVersion().flatMap(String.init(validatingCString:)) ?? "unknown"
}

/// A human-readable string describing the Swift Standard Library's version.
///
/// This value's format is platform-specific and is not meant to be
/// machine-readable. It is added to the output of a test run when using
/// an event writer.
///
/// This value is not part of the public interface of the testing library.
let swiftStandardLibraryVersion: String = {
  if #available(_swiftVersionAPI, *) {
    return String(describing: _SwiftStdlibVersion.current)
  }
  return "unknown"
}()

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
