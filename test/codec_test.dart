import 'dart:convert';
import 'dart:typed_data';

import 'package:packagekit_dart/packagekit_dart.dart';
import 'package:packagekit_dart/src/ffi/codec.dart';
import 'package:packagekit_dart/src/ffi/types.dart';
import 'package:test/test.dart';

/// Helper to build glaze-encoded binary payloads matching glaze_meta.h format.
class _PayloadBuilder {
  final _buf = BytesBuilder();

  void writeUint32(int v) {
    final d = ByteData(4)..setUint32(0, v, Endian.little);
    _buf.add(d.buffer.asUint8List());
  }

  void writeUint64(int v) {
    final d = ByteData(8)..setUint64(0, v, Endian.little);
    _buf.add(d.buffer.asUint8List());
  }

  void writeBool(bool v) {
    _buf.addByte(v ? 1 : 0);
  }

  void writeString(String s) {
    final bytes = utf8.encode(s);
    writeUint32(bytes.length);
    _buf.add(bytes);
  }

  void writeStringList(List<String> list) {
    writeUint32(list.length);
    for (final s in list) {
      writeString(s);
    }
  }

  Uint8List toBytes() => _buf.toBytes();
}

void main() {
  group('GlazeCodec.decode PkPackage', () {
    test('decodes package payload', () {
      final b = _PayloadBuilder()
        ..writeUint32(1) // info = installed
        ..writeString('bash;5.1;x86_64;fedora')
        ..writeString('GNU Bourne Again Shell');
      final pkg = GlazeCodec.decode<PkPackage>(b.toBytes(), 0);
      expect(pkg.info, PkInfo.installed);
      expect(pkg.id.name, 'bash');
      expect(pkg.id.version, '5.1');
      expect(pkg.id.arch, 'x86_64');
      expect(pkg.id.data, 'fedora');
      expect(pkg.summary, 'GNU Bourne Again Shell');
    });
  });

  group('GlazeCodec.decode PkProgress', () {
    test('decodes progress payload', () {
      final b = _PayloadBuilder()
        ..writeString('vim;9.0;x86_64;updates')
        ..writeUint32(8) // status = download
        ..writeUint32(42)
        ..writeBool(false);
      final p = GlazeCodec.decode<PkProgress>(b.toBytes(), 0);
      expect(p.packageId, 'vim;9.0;x86_64;updates');
      expect(p.status, PkStatus.download);
      expect(p.percentage, 42);
      expect(p.isItem, isFalse);
    });

    test('decodes item progress', () {
      final b = _PayloadBuilder()
        ..writeString('pkg;1;x;r')
        ..writeUint32(9)
        ..writeUint32(100)
        ..writeBool(true);
      final p = GlazeCodec.decode<PkProgress>(b.toBytes(), 0);
      expect(p.isItem, isTrue);
      expect(p.percentage, 100);
    });
  });

  group('GlazeCodec.decode PkPackageDetail', () {
    test('decodes details payload', () {
      final b = _PayloadBuilder()
        ..writeString('gcc;13.2;x86_64;fedora')
        ..writeString('GNU Compiler Collection')
        ..writeString('The GNU C and C++ compiler')
        ..writeString('https://gcc.gnu.org')
        ..writeString('GPL-3.0')
        ..writeString('Development/Languages')
        ..writeUint64(52428800); // 50 MiB
      final d = GlazeCodec.decode<PkPackageDetail>(b.toBytes(), 0);
      expect(d.id.name, 'gcc');
      expect(d.summary, 'GNU Compiler Collection');
      expect(d.description, 'The GNU C and C++ compiler');
      expect(d.url, 'https://gcc.gnu.org');
      expect(d.license, 'GPL-3.0');
      expect(d.group, 'Development/Languages');
      expect(d.size, 52428800);
      expect(d.sizeFormatted, '50.0 MiB');
    });
  });

  group('GlazeCodec.decode PkUpdateDetail', () {
    test('decodes update detail payload', () {
      final b = _PayloadBuilder()
        ..writeString('pkg;2.0;x86_64;updates')
        ..writeStringList(['pkg;1.0;x86_64;fedora'])
        ..writeStringList([])
        ..writeStringList(['https://vendor.example.com'])
        ..writeStringList(['https://bugs.example.com/123'])
        ..writeStringList(['https://cve.example.com/CVE-2024-1234'])
        ..writeUint32(1) // restart
        ..writeString('Security fix for CVE-2024-1234')
        ..writeString('* Fixed buffer overflow')
        ..writeUint32(2) // state
        ..writeString('2024-01-15')
        ..writeString('2024-01-16');
      final u = GlazeCodec.decode<PkUpdateDetail>(b.toBytes(), 0);
      expect(u.packageId, 'pkg;2.0;x86_64;updates');
      expect(u.updates, ['pkg;1.0;x86_64;fedora']);
      expect(u.obsoletes, isEmpty);
      expect(u.vendorUrls, hasLength(1));
      expect(u.bugzillaUrls, hasLength(1));
      expect(u.cveUrls, hasLength(1));
      expect(u.restart, 1);
      expect(u.updateText, 'Security fix for CVE-2024-1234');
      expect(u.changelog, '* Fixed buffer overflow');
      expect(u.state, 2);
      expect(u.issued, '2024-01-15');
      expect(u.updated, '2024-01-16');
    });
  });

  group('GlazeCodec.decode PkRepoDetail', () {
    test('decodes repo detail', () {
      final b = _PayloadBuilder()
        ..writeString('fedora')
        ..writeString('Fedora 39 - x86_64')
        ..writeBool(true);
      final r = GlazeCodec.decode<PkRepoDetail>(b.toBytes(), 0);
      expect(r.repoId, 'fedora');
      expect(r.description, 'Fedora 39 - x86_64');
      expect(r.enabled, isTrue);
    });

    test('decodes disabled repo', () {
      final b = _PayloadBuilder()
        ..writeString('testing')
        ..writeString('Testing repo')
        ..writeBool(false);
      final r = GlazeCodec.decode<PkRepoDetail>(b.toBytes(), 0);
      expect(r.enabled, isFalse);
    });
  });

  group('GlazeCodec.decode PkFiles', () {
    test('decodes file list', () {
      final b = _PayloadBuilder()
        ..writeString('bash;5.1;x86_64;fedora')
        ..writeStringList(['/usr/bin/bash', '/usr/share/man/man1/bash.1.gz']);
      final f = GlazeCodec.decode<PkFiles>(b.toBytes(), 0);
      expect(f.packageId, 'bash;5.1;x86_64;fedora');
      expect(f.files, hasLength(2));
      expect(f.files[0], '/usr/bin/bash');
    });

    test('decodes empty file list', () {
      final b = _PayloadBuilder()
        ..writeString('pkg;1;x;r')
        ..writeStringList([]);
      final f = GlazeCodec.decode<PkFiles>(b.toBytes(), 0);
      expect(f.files, isEmpty);
    });
  });

  group('GlazeCodec.decode PkErrorCode', () {
    test('decodes error code', () {
      final b = _PayloadBuilder()
        ..writeUint32(8) // packageNotFound
        ..writeString('Package not found in any repository');
      final e = GlazeCodec.decode<PkErrorCode>(b.toBytes(), 0);
      expect(e.code, 8);
      expect(e.details, 'Package not found in any repository');
    });
  });

  group('GlazeCodec.decode PkMessage', () {
    test('decodes message', () {
      final b = _PayloadBuilder()
        ..writeUint32(3)
        ..writeString('Cache is out of date');
      final m = GlazeCodec.decode<PkMessage>(b.toBytes(), 0);
      expect(m.type, 3);
      expect(m.details, 'Cache is out of date');
    });
  });

  group('GlazeCodec.decode PkEulaRequired', () {
    test('decodes EULA required', () {
      final b = _PayloadBuilder()
        ..writeString('eula-123')
        ..writeString('font;1.0;x86_64;nonfree')
        ..writeString('Font Corp')
        ..writeString('You must agree to the font license...');
      final e = GlazeCodec.decode<PkEulaRequired>(b.toBytes(), 0);
      expect(e.eulaId, 'eula-123');
      expect(e.packageId, 'font;1.0;x86_64;nonfree');
      expect(e.vendorName, 'Font Corp');
      expect(e.licenseAgreement, contains('font license'));
    });
  });

  group('GlazeCodec.decode PkRepoSigRequired', () {
    test('decodes repo sig required', () {
      final b = _PayloadBuilder()
        ..writeString('pkg;1.0;x86_64;repo')
        ..writeString('my-repo')
        ..writeString('https://keys.example.com/key.gpg')
        ..writeString('Admin <admin@example.com>')
        ..writeString('ABCD1234')
        ..writeString('ABCD 1234 EF56 7890')
        ..writeString('2024-01-01')
        ..writeUint32(1);
      final s = GlazeCodec.decode<PkRepoSigRequired>(b.toBytes(), 0);
      expect(s.packageId, 'pkg;1.0;x86_64;repo');
      expect(s.repositoryName, 'my-repo');
      expect(s.keyUrl, 'https://keys.example.com/key.gpg');
      expect(s.keyUserId, 'Admin <admin@example.com>');
      expect(s.keyId, 'ABCD1234');
      expect(s.keyFingerprint, 'ABCD 1234 EF56 7890');
      expect(s.keyTimestamp, '2024-01-01');
      expect(s.type, 1);
    });
  });

  group('GlazeCodec.decode PkRequireRestart', () {
    test('decodes require restart', () {
      final b = _PayloadBuilder()
        ..writeUint32(2)
        ..writeString('kernel;6.5;x86_64;updates');
      final r = GlazeCodec.decode<PkRequireRestart>(b.toBytes(), 0);
      expect(r.type, 2);
      expect(r.packageId, 'kernel;6.5;x86_64;updates');
    });
  });

  group('GlazeCodec.decode PkManagerProps', () {
    test('decodes manager props', () {
      final b = _PayloadBuilder()
        ..writeString('dnf')
        ..writeString('DNF backend')
        ..writeString('PackageKit Authors')
        ..writeUint64(0xFFFF)
        ..writeUint64(0xFFFF)
        ..writeUint64(0xFF)
        ..writeStringList(['application/x-rpm'])
        ..writeString('fedora;39;x86_64')
        ..writeUint32(4) // networkState
        ..writeBool(false) // locked
        ..writeUint32(1) // versionMajor
        ..writeUint32(2) // versionMinor
        ..writeUint32(6); // versionMicro
      final p = GlazeCodec.decode<PkManagerProps>(b.toBytes(), 0);
      expect(p.backendName, 'dnf');
      expect(p.backendDescription, 'DNF backend');
      expect(p.backendAuthor, 'PackageKit Authors');
      expect(p.roles, 0xFFFF);
      expect(p.filters, 0xFFFF);
      expect(p.groups, 0xFF);
      expect(p.mimeTypes, ['application/x-rpm']);
      expect(p.distroId, 'fedora;39;x86_64');
      expect(p.networkState, 4);
      expect(p.locked, isFalse);
      expect(p.versionMajor, 1);
      expect(p.versionMinor, 2);
      expect(p.versionMicro, 6);
    });
  });

  group('GlazeCodec.decode PkFinished', () {
    test('decodes finished', () {
      final b = _PayloadBuilder()
        ..writeUint32(1) // success
        ..writeUint32(1234);
      final f = GlazeCodec.decode<PkFinished>(b.toBytes(), 0);
      expect(f.exitCode, 1);
      expect(f.runtimeMs, 1234);
    });
  });

  group('GlazeCodec.decode with offset', () {
    test('respects non-zero offset', () {
      // Prepend 3 garbage bytes, then a PkFinished payload
      final prefix = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final b = _PayloadBuilder()
        ..writeUint32(2) // failed
        ..writeUint32(500);
      final combined = Uint8List.fromList([...prefix, ...b.toBytes()]);
      final f = GlazeCodec.decode<PkFinished>(combined, 3);
      expect(f.exitCode, 2);
      expect(f.runtimeMs, 500);
    });
  });

  group('GlazeCodec.decode unknown type', () {
    test('throws for unsupported type', () {
      final b = _PayloadBuilder()..writeUint32(0);
      expect(
        () => GlazeCodec.decode<String>(b.toBytes(), 0),
        throwsArgumentError,
      );
    });
  });

  group('GlazeCodec reader bounds check', () {
    test('throws on truncated data', () {
      // Only 2 bytes, but uint32 needs 4
      final data = Uint8List.fromList([0x01, 0x02]);
      expect(() => GlazeCodec.decode<PkFinished>(data, 0), throwsRangeError);
    });
  });

  group('GlazeCodec UTF-8 strings', () {
    test('decodes UTF-8 characters', () {
      final b = _PayloadBuilder()
        ..writeUint32(2) // available
        ..writeString('paquet;1.0;x86_64;dépôt')
        ..writeString('Résumé avec des caractères spéciaux');
      final pkg = GlazeCodec.decode<PkPackage>(b.toBytes(), 0);
      expect(pkg.id.data, 'dépôt');
      expect(pkg.summary, contains('caractères'));
    });
  });
}
