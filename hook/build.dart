// hook/build.dart
// SPDX-License-Identifier: Apache-2.0
//
// Compiles libpackagekit_nc.so via CMake and registers it as a CodeAsset.
// Supports Linux x64 and ARM64 (native or cross).
// Runs at build time on the consumer's machine.
//
// If the native build fails (missing dependencies, no compiler, etc.), the hook
// returns without adding a CodeAsset. The @Native FFI functions will throw
// at call time if the .so is not available, but unit tests using mocks are
// unaffected.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final os = input.config.code.targetOS;
    if (os != OS.linux) {
      return;
    }

    final arch = input.config.code.targetArchitecture;

    final cmakeArch = switch (arch) {
      Architecture.x64 => 'x86_64',
      Architecture.arm64 => 'aarch64',
      _ => throw UnsupportedError(
        'packagekit_dart does not support architecture: $arch',
      ),
    };

    // The bridge needs a C++ toolchain (cmake + ninja) and libsystemd's sd-bus.
    // When any is absent — Alpine/OpenRC, a minimal image, any non-systemd host
    // — skip cleanly: the PackageKit backend simply won't be available (which is
    // fine where it is unused; `emb deps` degrades, nothing else). Probing up
    // front also avoids a needless sdbus-cpp clone. Without this, a *missing*
    // tool throws ProcessException (only a present-but-failing tool is handled
    // below via exitCode), which fails the whole build hook and blocks install.
    if (!await _hasTool('cmake') ||
        !await _hasTool('ninja') ||
        !await _hasSdBus()) {
      stderr.writeln(
        'packagekit_dart: skipping native bridge — needs '
        'cmake + ninja + libsystemd/sd-bus (PackageKit backend unavailable).',
      );
      return;
    }

    final nativeDir = input.packageRoot.resolve('native/');

    // Ensure sdbus-cpp source is available.
    // In a git checkout the submodule may need initialising; from pub.dev
    // there is no .git directory so we clone the pinned commit directly.
    const sdbusRepo = 'https://github.com/Kistler-Group/sdbus-cpp.git';
    const sdbusCommit = '28b78822cfc5fbec4bd9906168493e9985f586ed';

    final sdbusDir = Directory.fromUri(
      nativeDir.resolve('third_party/sdbus-cpp/'),
    );
    final sdbusMarker = File.fromUri(sdbusDir.uri.resolve('CMakeLists.txt'));
    if (!sdbusMarker.existsSync()) {
      // Try git-submodule first (works in git checkouts).
      final submoduleInit = await Process.run('git', [
        'submodule',
        'update',
        '--init',
        '--recursive',
      ], workingDirectory: input.packageRoot.toFilePath());
      if (submoduleInit.exitCode != 0 || !sdbusMarker.existsSync()) {
        // Fall back to a direct clone at the pinned commit (pub.dev installs).
        if (sdbusDir.existsSync()) {
          await sdbusDir.delete(recursive: true);
        }
        final clone = await Process.run('git', [
          'clone',
          '--depth',
          '1',
          sdbusRepo,
          sdbusDir.path,
        ]);
        if (clone.exitCode != 0) {
          stderr.writeln(
            'packagekit_dart: failed to clone sdbus-cpp\n${clone.stderr}',
          );
          return;
        }
        final checkout = await Process.run('git', [
          'checkout',
          sdbusCommit,
        ], workingDirectory: sdbusDir.path);
        if (checkout.exitCode != 0) {
          // Shallow clone may not have the commit; do a full fetch.
          await Process.run('git', [
            'fetch',
            '--unshallow',
          ], workingDirectory: sdbusDir.path);
          final retry = await Process.run('git', [
            'checkout',
            sdbusCommit,
          ], workingDirectory: sdbusDir.path);
          if (retry.exitCode != 0) {
            stderr.writeln(
              'packagekit_dart: failed to checkout sdbus-cpp $sdbusCommit\n${retry.stderr}',
            );
            return;
          }
        }
      }
    }

    final buildDir = Directory.fromUri(
      input.outputDirectory.resolve('pk_nc_build_$cmakeArch/'),
    );
    await buildDir.create(recursive: true);

    // Configure CMake
    final configure = await Process.run('cmake', [
      nativeDir.toFilePath(),
      '-GNinja',
      '-DCMAKE_BUILD_TYPE=Release',
      '-DBUILD_TESTING=OFF',
      '-DCMAKE_INSTALL_PREFIX=${buildDir.path}/install',
    ], workingDirectory: buildDir.path);
    if (configure.exitCode != 0) {
      stderr.writeln(
        'packagekit_dart: cmake configure failed...\n${configure.stderr}',
      );
      return;
    }

    // Build
    final buildResult = await Process.run('cmake', [
      '--build',
      '.',
      '--parallel',
    ], workingDirectory: buildDir.path);
    if (buildResult.exitCode != 0) {
      stderr.writeln(
        'packagekit_dart: cmake build failed...\n${buildResult.stderr}',
      );
      return;
    }

    // Install
    final installResult = await Process.run('cmake', [
      '--install',
      '.',
    ], workingDirectory: buildDir.path);
    if (installResult.exitCode != 0) {
      stderr.writeln(
        'packagekit_dart: cmake install failed...\n${installResult.stderr}',
      );
      return;
    }

    final so = Uri.file('${buildDir.path}/install/lib/libpackagekit_nc.so');

    output.assets.code.add(
      CodeAsset(
        package: 'packagekit_dart',
        name: 'src/packagekit_nc.dart',
        file: so,
        linkMode: DynamicLoadingBundled(),
      ),
    );
  });
}

/// Whether [tool] is runnable (present on PATH). `Process.run` throws
/// [ProcessException] when the executable is missing, so a missing tool must be
/// caught rather than left to fail the build.
Future<bool> _hasTool(String tool) async {
  try {
    final result = await Process.run(tool, ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Whether libsystemd's sd-bus is available to link the bridge against.
Future<bool> _hasSdBus() async {
  try {
    final result = await Process.run('pkg-config', ['--exists', 'libsystemd']);
    return result.exitCode == 0;
  } on ProcessException {
    return false; // pkg-config absent → assume no sd-bus
  }
}
