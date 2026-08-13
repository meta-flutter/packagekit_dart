import 'package:packagekit_dart/packagekit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PkFilter', () {
    test('all values have distinct bits', () {
      final seen = <int>{};
      for (final f in PkFilter.values) {
        if (f == PkFilter.none) continue;
        expect(
          seen.contains(f.value),
          isFalse,
          reason: '${f.name} has duplicate value ${f.value}',
        );
        seen.add(f.value);
      }
    });

    test('none is zero', () {
      expect(PkFilter.none.value, 0);
    });

    test('combine all filters', () {
      final all = PkFilter.combine(PkFilter.values);
      for (final f in PkFilter.values) {
        if (f == PkFilter.none) continue;
        expect(all & f.value, isNonZero, reason: '${f.name} not in combined');
      }
    });
  });

  group('PkTransactionFlag', () {
    test('all values have distinct bits', () {
      final seen = <int>{};
      for (final f in PkTransactionFlag.values) {
        expect(seen.contains(f.value), isFalse);
        seen.add(f.value);
      }
    });

    test('combine empty', () {
      expect(PkTransactionFlag.combine([]), 0);
    });

    test('combine all', () {
      final all = PkTransactionFlag.combine(PkTransactionFlag.values);
      for (final f in PkTransactionFlag.values) {
        expect(all & f.value, isNonZero);
      }
    });
  });

  group('PkInfo', () {
    test('all values roundtrip through fromInt', () {
      for (final info in PkInfo.values) {
        expect(PkInfo.fromInt(info.value), info);
      }
    });
  });

  group('PkStatus', () {
    test('all values roundtrip through fromInt', () {
      for (final s in PkStatus.values) {
        expect(PkStatus.fromInt(s.value), s);
      }
    });
  });

  group('PkExit', () {
    test('all values roundtrip through fromInt', () {
      for (final e in PkExit.values) {
        expect(PkExit.fromInt(e.value), e);
      }
    });
  });

  group('PkError', () {
    test('all values roundtrip through fromInt', () {
      for (final e in PkError.values) {
        expect(PkError.fromInt(e.value), e);
      }
    });

    test('values are sequential from 0', () {
      for (var i = 0; i < PkError.values.length; i++) {
        expect(PkError.values[i].value, i);
      }
    });
  });

  group('PkProgress', () {
    test('progressLabel with known percentage', () {
      const p = PkProgress(
        packageId: '',
        status: PkStatus.install,
        percentage: 75,
        isItem: false,
      );
      expect(p.progressLabel, contains('75%'));
      expect(p.progressLabel, contains('install'));
    });

    test('progressLabel with unknown percentage', () {
      const p = PkProgress(
        packageId: '',
        status: PkStatus.query,
        percentage: 101,
        isItem: false,
      );
      expect(p.progressLabel, contains('query'));
    });

    test('percentageKnown boundary at 100', () {
      const p = PkProgress(
        packageId: '',
        status: PkStatus.running,
        percentage: 100,
        isItem: false,
      );
      expect(p.percentageKnown, isTrue);
    });
  });
}
