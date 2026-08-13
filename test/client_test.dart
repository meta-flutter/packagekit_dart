import 'package:packagekit_dart/packagekit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PkFilter', () {
    test('combine empty', () {
      expect(PkFilter.combine([]), 0);
    });

    test('combine single', () {
      expect(PkFilter.combine([PkFilter.installed]), PkFilter.installed.value);
    });

    test('combine multiple', () {
      final result = PkFilter.combine([PkFilter.installed, PkFilter.newest]);
      expect(result, PkFilter.installed.value | PkFilter.newest.value);
    });
  });

  group('PkTransactionFlag', () {
    test('combine with simulate', () {
      final flags = PkTransactionFlag.combine([
        PkTransactionFlag.onlyTrusted,
        PkTransactionFlag.simulate,
      ]);
      expect(flags & PkTransactionFlag.simulate.value, isNonZero);
      expect(flags & PkTransactionFlag.onlyTrusted.value, isNonZero);
    });
  });

  group('PkInfo', () {
    test('fromInt known', () {
      expect(PkInfo.fromInt(1), PkInfo.installed);
      expect(PkInfo.fromInt(2), PkInfo.available);
      expect(PkInfo.fromInt(8), PkInfo.security);
    });

    test('fromInt unknown', () {
      expect(PkInfo.fromInt(999), PkInfo.unknown);
    });
  });

  group('PkStatus', () {
    test('fromInt known', () {
      expect(PkStatus.fromInt(8), PkStatus.download);
      expect(PkStatus.fromInt(9), PkStatus.install);
    });

    test('fromInt unknown', () {
      expect(PkStatus.fromInt(999), PkStatus.unknown);
    });
  });

  group('PkExit', () {
    test('fromInt', () {
      expect(PkExit.fromInt(1), PkExit.success);
      expect(PkExit.fromInt(2), PkExit.failed);
      expect(PkExit.fromInt(999), PkExit.unknown);
    });
  });

  group('PkError', () {
    test('fromInt', () {
      expect(PkError.fromInt(8), PkError.packageNotFound);
      expect(PkError.fromInt(999), PkError.unknown);
    });
  });

  group('Exceptions', () {
    test('PkException toString', () {
      const e = PkException('test');
      expect(e.toString(), contains('test'));
    });

    test('PkServiceUnavailableException', () {
      const e = PkServiceUnavailableException('no daemon');
      expect(e.toString(), contains('no daemon'));
    });

    test('PkTransactionException', () {
      const e = PkTransactionException(
        'failed',
        exit: PkExit.failed,
        runtimeMs: 123,
      );
      expect(e.toString(), contains('failed'));
      expect(e.exit, PkExit.failed);
      expect(e.runtimeMs, 123);
    });
  });
}
