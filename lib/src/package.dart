// package.dart

import 'enums.dart';

/// Parsed PackageKit package identifier: "name;version;arch;data".
class PkPackageId {
  /// The package name (e.g. "firefox").
  final String name;

  /// The package version string.
  final String version;

  /// The CPU architecture (e.g. "x86_64", "aarch64", "noarch").
  final String arch;

  /// Backend-specific source identifier, e.g. "fedora", "@System", "flathub".
  final String data;

  /// Creates a [PkPackageId] from its individual components.
  const PkPackageId({
    required this.name,
    required this.version,
    required this.arch,
    required this.data,
  });

  /// Parses a semicolon-delimited package ID string ("name;version;arch;data").
  factory PkPackageId.parse(String id) {
    final parts = id.split(';');
    if (parts.length != 4) throw FormatException('Invalid package_id: $id');
    return PkPackageId(
      name: parts[0],
      version: parts[1],
      arch: parts[2],
      data: parts[3],
    );
  }

  /// The raw semicolon-delimited package ID string.
  String get raw => '$name;$version;$arch;$data';

  @override
  String toString() => '$name-$version.$arch';
}

/// A package returned by Package signals.
class PkPackage {
  /// The package info state (installed, available, etc.).
  final PkInfo info;

  /// The parsed package identifier.
  final PkPackageId id;

  /// One-line package summary.
  final String summary;

  /// Creates a [PkPackage] instance.
  const PkPackage({
    required this.info,
    required this.id,
    required this.summary,
  });
}

/// Detailed information returned by the Details signal.
class PkPackageDetail {
  /// The parsed package identifier.
  final PkPackageId id;

  /// One-line package summary.
  final String summary;

  /// Full package description.
  final String description;

  /// Upstream project URL.
  final String url;

  /// License identifier (e.g. "GPL-2.0", "MIT").
  final String license;

  /// Package group (e.g. "Development/Libraries").
  final String group;

  /// Installed size in bytes; 0 if unknown.
  final int size;

  /// Creates a [PkPackageDetail] instance.
  const PkPackageDetail({
    required this.id,
    required this.summary,
    required this.description,
    required this.url,
    required this.license,
    required this.group,
    required this.size,
  });

  /// Human-readable formatted size string (e.g. "12.3 MiB").
  String get sizeFormatted => size == 0
      ? 'unknown'
      : size >= 1 << 30
      ? '${(size / (1 << 30)).toStringAsFixed(1)} GiB'
      : size >= 1 << 20
      ? '${(size / (1 << 20)).toStringAsFixed(1)} MiB'
      : '${(size / 1024).toStringAsFixed(1)} KiB';
}
