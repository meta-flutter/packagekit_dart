import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:packagekit_dart/packagekit_dart.dart';
import 'package:packagekit_dart/src/internal/dispatcher.dart';
import 'package:test/test.dart';

/// Helper to build glaze-encoded binary payloads.
class _PayloadBuilder {
  final _buf = BytesBuilder();

  void writeByte(int v) => _buf.addByte(v);

  void writeUint32(int v) {
    final d = ByteData(4)..setUint32(0, v, Endian.little);
    _buf.add(d.buffer.asUint8List());
  }

  void writeUint64(int v) {
    final d = ByteData(8)..setUint64(0, v, Endian.little);
    _buf.add(d.buffer.asUint8List());
  }

  void writeBool(bool v) => _buf.addByte(v ? 1 : 0);

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

Uint8List _makePackageMsg(int info, String pkgId, String summary) {
  final b = _PayloadBuilder()
    ..writeByte(0x01)
    ..writeUint32(info)
    ..writeString(pkgId)
    ..writeString(summary);
  return b.toBytes();
}

Uint8List _makeProgressMsg(String pkgId, int status, int pct, bool isItem) {
  final b = _PayloadBuilder()
    ..writeByte(0x02)
    ..writeString(pkgId)
    ..writeUint32(status)
    ..writeUint32(pct)
    ..writeBool(isItem);
  return b.toBytes();
}

Uint8List _makeDetailsMsg(
  String pkgId,
  String summary,
  String desc,
  String url,
  String license,
  String group,
  int size,
) {
  final b = _PayloadBuilder()
    ..writeByte(0x03)
    ..writeString(pkgId)
    ..writeString(summary)
    ..writeString(desc)
    ..writeString(url)
    ..writeString(license)
    ..writeString(group)
    ..writeUint64(size);
  return b.toBytes();
}

Uint8List _makeRepoDetailMsg(String repoId, String desc, bool enabled) {
  final b = _PayloadBuilder()
    ..writeByte(0x05)
    ..writeString(repoId)
    ..writeString(desc)
    ..writeBool(enabled);
  return b.toBytes();
}

Uint8List _makeFilesMsg(String pkgId, List<String> files) {
  final b = _PayloadBuilder()
    ..writeByte(0x06)
    ..writeString(pkgId)
    ..writeStringList(files);
  return b.toBytes();
}

Uint8List _makeErrorCodeMsg(int code, String details) {
  final b = _PayloadBuilder()
    ..writeByte(0x07)
    ..writeUint32(code)
    ..writeString(details);
  return b.toBytes();
}

Uint8List _makeMessageMsg(int type, String details) {
  final b = _PayloadBuilder()
    ..writeByte(0x08)
    ..writeUint32(type)
    ..writeString(details);
  return b.toBytes();
}

Uint8List _makeEulaMsg(
  String eulaId,
  String pkgId,
  String vendor,
  String agreement,
) {
  final b = _PayloadBuilder()
    ..writeByte(0x09)
    ..writeString(eulaId)
    ..writeString(pkgId)
    ..writeString(vendor)
    ..writeString(agreement);
  return b.toBytes();
}

Uint8List _makeRepoSigMsg(
  String pkgId,
  String repoName,
  String keyUrl,
  String userId,
  String keyId,
  String fp,
  String ts,
  int type,
) {
  final b = _PayloadBuilder()
    ..writeByte(0x0A)
    ..writeString(pkgId)
    ..writeString(repoName)
    ..writeString(keyUrl)
    ..writeString(userId)
    ..writeString(keyId)
    ..writeString(fp)
    ..writeString(ts)
    ..writeUint32(type);
  return b.toBytes();
}

Uint8List _makeRestartMsg(int type, String pkgId) {
  final b = _PayloadBuilder()
    ..writeByte(0x0B)
    ..writeUint32(type)
    ..writeString(pkgId);
  return b.toBytes();
}

Uint8List _makeUpdateDetailMsg() {
  final b = _PayloadBuilder()
    ..writeByte(0x04)
    ..writeString('pkg;2.0;x86_64;updates')
    ..writeStringList(['pkg;1.0;x86_64;f'])
    ..writeStringList([])
    ..writeStringList([])
    ..writeStringList([])
    ..writeStringList([])
    ..writeUint32(0)
    ..writeString('update text')
    ..writeString('changelog')
    ..writeUint32(0)
    ..writeString('2024-01-01')
    ..writeString('2024-01-02');
  return b.toBytes();
}

Uint8List _makeFinishedMsg(int exitCode, int runtimeMs) {
  final b = _PayloadBuilder()
    ..writeByte(0x20)
    ..writeUint32(exitCode)
    ..writeUint32(runtimeMs);
  return b.toBytes();
}

Uint8List _makeSentinelMsg() => Uint8List.fromList([0xFF]);

Uint8List _makeManagerPropsMsg() {
  final b = _PayloadBuilder()
    ..writeByte(0x0C)
    ..writeString('dnf')
    ..writeString('DNF backend')
    ..writeString('Author')
    ..writeUint64(0xFF)
    ..writeUint64(0xFF)
    ..writeUint64(0xFF)
    ..writeStringList(['application/x-rpm'])
    ..writeString('fedora;39;x86_64')
    ..writeUint32(4)
    ..writeBool(false)
    ..writeUint32(1)
    ..writeUint32(2)
    ..writeUint32(6);
  return b.toBytes();
}

void main() {
  group('TransactionDispatcher', () {
    late TransactionDispatcher d;

    setUp(() => d = TransactionDispatcher());
    tearDown(() => d.close());

    test('dispatches PkPackage (0x01)', () async {
      final c = Completer<PkPackage>();
      d.packages.stream.listen(c.complete);
      d.dispatch(_makePackageMsg(1, 'bash;5.1;x86_64;fedora', 'Shell'));
      final pkg = await c.future;
      expect(pkg.info, PkInfo.installed);
      expect(pkg.id.name, 'bash');
      expect(pkg.summary, 'Shell');
    });

    test('dispatches PkProgress (0x02)', () async {
      final c = Completer<PkProgress>();
      d.progress.stream.listen(c.complete);
      d.dispatch(_makeProgressMsg('pkg;1;x;r', 8, 50, false));
      final p = await c.future;
      expect(p.status, PkStatus.download);
      expect(p.percentage, 50);
      expect(p.isItem, isFalse);
    });

    test('dispatches PkPackageDetail (0x03)', () async {
      final c = Completer<PkPackageDetail>();
      d.details.stream.listen(c.complete);
      d.dispatch(
        _makeDetailsMsg(
          'gcc;13;x86_64;f',
          'GCC',
          'Compiler',
          'url',
          'GPL',
          'Dev',
          1024,
        ),
      );
      final det = await c.future;
      expect(det.id.name, 'gcc');
      expect(det.description, 'Compiler');
    });

    test('dispatches PkUpdateDetail (0x04)', () async {
      final c = Completer<PkUpdateDetail>();
      d.updateDetails.stream.listen(c.complete);
      d.dispatch(_makeUpdateDetailMsg());
      final u = await c.future;
      expect(u.packageId, 'pkg;2.0;x86_64;updates');
      expect(u.updateText, 'update text');
    });

    test('dispatches PkRepoDetail (0x05)', () async {
      final c = Completer<PkRepoDetail>();
      d.repoDetails.stream.listen(c.complete);
      d.dispatch(_makeRepoDetailMsg('fedora', 'Fedora 39', true));
      final r = await c.future;
      expect(r.repoId, 'fedora');
      expect(r.enabled, isTrue);
    });

    test('dispatches PkFiles (0x06)', () async {
      final c = Completer<PkFiles>();
      d.files.stream.listen(c.complete);
      d.dispatch(_makeFilesMsg('pkg;1;x;r', ['/usr/bin/pkg']));
      final f = await c.future;
      expect(f.files, ['/usr/bin/pkg']);
    });

    test('dispatches PkErrorCode (0x07)', () async {
      final c = Completer<PkErrorCode>();
      d.errors.stream.listen(c.complete);
      d.dispatch(_makeErrorCodeMsg(8, 'Not found'));
      final e = await c.future;
      expect(e.code, 8);
      expect(e.details, 'Not found');
    });

    test('dispatches PkMessage (0x08)', () async {
      final c = Completer<PkMessage>();
      d.messages.stream.listen(c.complete);
      d.dispatch(_makeMessageMsg(3, 'Cache stale'));
      final m = await c.future;
      expect(m.type, 3);
    });

    test('dispatches PkEulaRequired (0x09)', () async {
      final c = Completer<PkEulaRequired>();
      d.eulaRequired.stream.listen(c.complete);
      d.dispatch(_makeEulaMsg('e1', 'pkg;1;x;r', 'Vendor', 'Agree'));
      final e = await c.future;
      expect(e.eulaId, 'e1');
      expect(e.vendorName, 'Vendor');
    });

    test('dispatches PkRepoSigRequired (0x0A)', () async {
      final c = Completer<PkRepoSigRequired>();
      d.repoSigRequired.stream.listen(c.complete);
      d.dispatch(
        _makeRepoSigMsg(
          'pkg;1;x;r',
          'repo',
          'url',
          'user',
          'id',
          'fp',
          'ts',
          1,
        ),
      );
      final s = await c.future;
      expect(s.repositoryName, 'repo');
    });

    test('dispatches PkRequireRestart (0x0B)', () async {
      final c = Completer<PkRequireRestart>();
      d.requireRestart.stream.listen(c.complete);
      d.dispatch(_makeRestartMsg(2, 'kernel;6.5;x86_64;u'));
      final r = await c.future;
      expect(r.type, 2);
    });

    test('dispatches Finished success (0x20)', () async {
      d.dispatch(_makeFinishedMsg(1, 500));
      final result = await d.done.future;
      expect(result.exit, PkExit.success);
      expect(result.runtimeMs, 500);
    });

    test('dispatches Finished failure (0x20)', () async {
      d.dispatch(_makeFinishedMsg(2, 100));
      expect(
        d.done.future,
        throwsA(
          isA<PkTransactionException>().having(
            (e) => e.exit,
            'exit',
            PkExit.failed,
          ),
        ),
      );
    });

    test('sentinel (0xFF) closes streams', () async {
      d.dispatch(_makeFinishedMsg(1, 0));
      d.dispatch(_makeSentinelMsg());
      // Give microtask time to close.
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      expect(d.finished, isTrue);
      expect(d.packages.isClosed, isTrue);
    });

    test('multiple packages before finish', () async {
      final pkgs = <PkPackage>[];
      d.packages.stream.listen(pkgs.add);
      d.dispatch(_makePackageMsg(1, 'a;1;x;r', 'A'));
      d.dispatch(_makePackageMsg(2, 'b;2;x;r', 'B'));
      d.dispatch(_makePackageMsg(1, 'c;3;x;r', 'C'));
      d.dispatch(_makeFinishedMsg(1, 100));
      d.dispatch(_makeSentinelMsg());
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      expect(pkgs, hasLength(3));
      expect(pkgs[0].info, PkInfo.installed);
      expect(pkgs[1].info, PkInfo.available);
    });

    test('decode error completes done with PkException', () async {
      // Send truncated message — discriminator 0x01 but no payload.
      d.dispatch(Uint8List.fromList([0x01]));
      expect(d.done.future, throwsA(isA<PkException>()));
    });

    test('duplicate finish is ignored', () async {
      d.dispatch(_makeFinishedMsg(1, 100));
      d.dispatch(_makeFinishedMsg(2, 200)); // Should be ignored.
      final result = await d.done.future;
      expect(result.exit, PkExit.success);
    });
  });

  group('dispatchManagerEvent', () {
    test('returns null for non-Uint8List', () {
      expect(dispatchManagerEvent('not bytes'), isNull);
      expect(dispatchManagerEvent(42), isNull);
      expect(dispatchManagerEvent(null), isNull);
    });

    test('decodes manager props (0x0C)', () {
      final msg = _makeManagerPropsMsg();
      final event = dispatchManagerEvent(msg);
      expect(event, isA<ManagerPropsEvent>());
      final props = (event as ManagerPropsEvent).props;
      expect(props.backendName, 'dnf');
      expect(props.versionMajor, 1);
      expect(props.versionMinor, 2);
      expect(props.versionMicro, 6);
    });

    test('decodes updates changed (0xD0)', () {
      final msg = Uint8List.fromList([0xD0]);
      expect(dispatchManagerEvent(msg), isA<ManagerUpdatesChangedEvent>());
    });

    test('decodes repo list changed (0xD1)', () {
      final msg = Uint8List.fromList([0xD1]);
      expect(dispatchManagerEvent(msg), isA<ManagerRepoListChangedEvent>());
    });

    test('decodes network state changed (0xD2)', () {
      final b = _PayloadBuilder()
        ..writeByte(0xD2)
        ..writeUint32(3);
      final event = dispatchManagerEvent(b.toBytes());
      expect(event, isA<ManagerNetworkStateChangedEvent>());
      expect((event as ManagerNetworkStateChangedEvent).state, 3);
    });

    test('returns null for unknown discriminator', () {
      final msg = Uint8List.fromList([0xEE]);
      expect(dispatchManagerEvent(msg), isNull);
    });
  });
}
