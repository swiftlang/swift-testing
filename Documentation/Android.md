# Running tests for Android

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
-->

To run tests for Android on your own machine, you build them with the Swift SDK
for Android, copy them to an Android emulator, and run them there with `adb`.

Install a Swift toolchain and the matching Swift SDK for Android by following
[these instructions](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).
The examples below use the `swift-DEVELOPMENT-SNAPSHOT-2026-11-01-a` snapshot of
the main branch. You can also use a later snapshot, such as a
`swift-6.5.x-DEVELOPMENT-SNAPSHOT-2026-11-dd-a` snapshot of the release branch,
or the `swift-6.5-RELEASE` release when they're available. Install the toolchain
and the Swift SDK for Android with the same tag. Snapshots are listed under
[Development Snapshots](https://www.swift.org/install/macos/#development-snapshots)
on swift.org. With `swiftly`, use `swiftly install main-snapshot` for the
toolchain.

You also need the
[Android SDK command-line tools](https://developer.android.com/studio#command-line-tools-only),
which include `sdkmanager` and `avdmanager` and are available for macOS, Linux
and Windows. The commands below use `sdkmanager` to install `adb` and the
emulator. The emulator runs on macOS, x86-64 Linux and x86-64 Windows. The
examples use Android API level 33 and assume `$ANDROID_HOME` points at your
Android SDK. Use API level 33 or later: on earlier versions of Android, the
testing library can't capture backtraces.

The command-line tools need JDK 17 or later. If you're installing them for the
first time, choose a directory for the Android SDK and move the tools into
`cmdline-tools/latest` inside it, as the
[`sdkmanager` documentation](https://developer.android.com/tools/sdkmanager)
describes:

```sh
export ANDROID_HOME="$HOME/android-sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"
unzip commandlinetools-*_latest.zip -d "$ANDROID_HOME/cmdline-tools"
mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" \
  "$ANDROID_HOME/cmdline-tools/latest"
```

## Start an emulator

The emulator runs at full speed only when its architecture matches your
machine: use `arm64-v8a` on Apple silicon (or other ARM64-based hardware) and
`x86_64` on an x86-64 machine. To install a system image and create an
emulator, use the following commands, setting `ABI` to your machine's
architecture:

```sh
ABI=arm64-v8a  # or x86_64
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
sdkmanager --install "emulator" "platform-tools" \
  "system-images;android-33;default;$ABI"
echo no | avdmanager create avd -n swift-tests \
  -k "system-images;android-33;default;$ABI"
emulator -avd swift-tests -no-window -no-snapshot -no-audio &
adb wait-for-device shell \
  'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done'
```

If more than one emulator or device is connected, set `ANDROID_SERIAL` to the
one to use, such as `export ANDROID_SERIAL=emulator-5554`. Run `adb devices`
to list their serial numbers.

## Build the tests

Build the tests with the Swift SDK for Android. Set `SWIFT_SDK` to its name as
`swift sdk list` shows it, and `TRIPLE` to the target triple that matches the
emulator's architecture and API level. On an x86-64 machine, use
`x86_64-unknown-linux-android33`. The commands below use both variables, so run
them in the same shell:

```sh
SWIFT_SDK=swift-DEVELOPMENT-SNAPSHOT-2026-11-01-a_android
TRIPLE=aarch64-unknown-linux-android33  # or x86_64-unknown-linux-android33
swift build --build-tests --swift-sdk "$SWIFT_SDK" --triple "$TRIPLE"
```

If only one Swift SDK for Android is installed, `--swift-sdk "$TRIPLE"` also
works. With more than one, the triple alone matches all of them and the build
stops with an error.

## Copy the tests to the emulator

The emulator needs the test runner and the libraries it loads: the ones built
for your package, the Swift runtime from the Swift SDK, and `libc++_shared.so`
from the Android NDK. Set `ANDROID_NDK_HOME` to the NDK's directory in this
shell, as in the getting-started instructions above.
`swift sdk configure --show-configuration` prints where the Swift SDK keeps the
Swift runtime. Copy everything into one folder and push it to the emulator:

```sh
CONFIG="$(swift sdk configure --show-configuration "$SWIFT_SDK" "$TRIPLE")"
SWIFT_RESOURCES="$(echo "$CONFIG" | sed -n 's/^swiftResourcesPath: //p')"
ARCH="${TRIPLE%%-*}"
BIN="$(swift build --show-bin-path \
  --swift-sdk "$SWIFT_SDK" --triple "$TRIPLE")"

mkdir -p android-tests
cp "$BIN"/*-test-runner "$BIN"/*.so android-tests/
cp "$SWIFT_RESOURCES"/android/*.so android-tests/
NDK_PREBUILT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt"
cp "$NDK_PREBUILT"/*/sysroot/usr/lib/"$ARCH"-linux-android/libc++_shared.so \
  android-tests/
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
adb shell "cd /data/local/tmp/android-tests && \
  ./{YOURTARGET}-test-runner --testing-library swift-testing"
```

Each test target has its own test runner. If your package has more than one,
run each of them. For example, this repository's tests build into
`TestingTests-test-runner`, `TestingMacrosTests-test-runner` and
`NonisolatedNonsendingByDefaultTests-test-runner`.

You can pass command-line options of the testing library after the runner's
name. For example, to list all tests and to filter them by name, use the
following commands:

```sh
adb shell "cd /data/local/tmp/android-tests && \
  ./{YOURTARGET}-test-runner --testing-library swift-testing list"
adb shell "cd /data/local/tmp/android-tests && \
  ./{YOURTARGET}-test-runner --testing-library swift-testing \
  --filter foodTruckExists"
```

The pull request checks for this repository run the same steps in CI, using
[`android-emulator-tests.sh`](https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/scripts/android/android-emulator-tests.sh)
from `swiftlang/github-workflows`.
