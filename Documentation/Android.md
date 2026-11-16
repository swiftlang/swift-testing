# Running tests for Android

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

<!-- NOTE: The voice of this document is directed at the second person ("you")
because it provides instructions the reader must follow directly. -->

To run tests for Android on your own machine, you build them with the Swift SDK
for Android, copy them to an Android emulator, and run them there with `adb`.

Install a Swift toolchain and the matching Swift SDK for Android by following
[these instructions](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).
You also need the Android SDK command-line tools, which include `sdkmanager`,
`avdmanager`, `emulator` and `adb`. The examples below use Swift 6.4.1 and
Android API level 33, and assume `$ANDROID_HOME` points at your Android SDK.
Use API level 33 or later: on earlier versions of Android, the testing library
can't capture backtraces.

## Start an emulator

The emulator runs at full speed only when its architecture matches your
machine: use `arm64-v8a` on Apple silicon and `x86_64` on an x86-64 machine.
To install a system image and create an emulator on Apple silicon, use the
following commands:

```sh
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
sdkmanager --install "emulator" "platform-tools" "system-images;android-33;default;arm64-v8a"
echo no | avdmanager create avd -n swift-tests -k "system-images;android-33;default;arm64-v8a"
emulator -avd swift-tests -no-window -no-snapshot -no-audio &
adb wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done'
```

If more than one emulator or device is connected, set `ANDROID_SERIAL` to the
one to use, such as `export ANDROID_SERIAL=emulator-5554`. Run `adb devices`
to list their serial numbers.

## Build the tests

Build the tests with the Swift SDK for Android, using the target triple that
matches the emulator's architecture and API level. On an x86-64 machine, use
`x86_64-unknown-linux-android33` here and below:

```sh
swift build --build-tests --swift-sdk aarch64-unknown-linux-android33
```

## Copy the tests to the emulator

The emulator needs the test runner and the libraries it loads: the ones built
for your package, the Swift runtime from the Swift SDK, and `libc++_shared.so`
from the Android NDK. `swift sdk configure --show-configuration` prints where
the Swift SDK keeps them. Copy everything into one folder and push it to the
emulator:

```sh
SWIFT_SDK=swift-6.4.1-RELEASE_android
TRIPLE=aarch64-unknown-linux-android33
CONFIG="$(swift sdk configure --show-configuration "$SWIFT_SDK" "$TRIPLE")"
SDK_ROOT="$(echo "$CONFIG" | sed -n 's/^sdkRootPath: //p')"
SWIFT_RESOURCES="$(echo "$CONFIG" | sed -n 's/^swiftResourcesPath: //p')"
ARCH="${TRIPLE%%-*}"
BIN="$(swift build --show-bin-path --swift-sdk "$TRIPLE")"

mkdir -p android-tests
cp "$BIN"/*-test-runner "$BIN"/*.so android-tests/
cp "$SWIFT_RESOURCES"/android/*.so android-tests/
cp "$SDK_ROOT"/usr/lib/"$ARCH"-linux-android/libc++_shared.so android-tests/
adb push android-tests /data/local/tmp/android-tests
```

With `--build-system native`, `swift build` produces a single
`{YOURPACKAGE}PackageTests.xctest` file instead of a `-test-runner` executable
and its libraries. In that case, copy that file in place of them and run it the
same way.

## Run the tests

Run the test runner on the emulator with `adb shell`, replacing
`{YOURTARGET}` with the name of your test target, such as `FoodTruckTests`:

```sh
adb shell "cd /data/local/tmp/android-tests && ./{YOURTARGET}-test-runner --testing-library swift-testing"
```

Each test target has its own test runner. If your package has more than one,
run each of them. For example, this repository's tests build into
`TestingTests-test-runner`, `TestingMacrosTests-test-runner` and
`NonisolatedNonsendingByDefaultTests-test-runner`.

> [!NOTE]
> With the Swift SDKs for Android from Swift 6.4.1 and 6.4.2, a test runner that
> imports `FoundationXML` fails to start with the error `cannot locate symbol
> "deflateInit2_"`. To work around this, load the system's `libz.so` first by
> adding `LD_PRELOAD=libz.so` before the runner's name.

You can pass command-line options of the testing library after the runner's
name. For example, to list all tests and to filter them by name, use the
following commands:

```sh
adb shell "cd /data/local/tmp/android-tests && ./{YOURTARGET}-test-runner --testing-library swift-testing --list-tests"
adb shell "cd /data/local/tmp/android-tests && ./{YOURTARGET}-test-runner --testing-library swift-testing --filter foodTruckExists"
```

The pull request checks for this repository run the same steps in CI, using
[`android-emulator-tests.sh`](https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/scripts/android/android-emulator-tests.sh)
from `swiftlang/github-workflows`.
