import 'package:packagekit_dart/packagekit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PkInstallPlan', () {
    test('empty plan', () {
      const plan = PkInstallPlan(
        installing: [],
        updating: [],
        removing: [],
        reinstalling: [],
        downgrading: [],
        obsoleting: [],
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.changeCount, 0);
      expect(plan.allIds, isEmpty);
    });

    test('plan with installs', () {
      final plan = PkInstallPlan(
        installing: [
          PkPackage(
            info: PkInfo.installing,
            id: PkPackageId.parse('vim;9.0;x86_64;fedora'),
            summary: 'Editor',
          ),
          PkPackage(
            info: PkInfo.installing,
            id: PkPackageId.parse('vim-common;9.0;x86_64;fedora'),
            summary: 'Common files',
          ),
        ],
        updating: [],
        removing: [],
        reinstalling: [],
        downgrading: [],
        obsoleting: [],
      );
      expect(plan.isEmpty, isFalse);
      expect(plan.changeCount, 2);
      expect(plan.allIds, hasLength(2));
      expect(plan.allIds.first, 'vim;9.0;x86_64;fedora');
    });

    test('plan toString', () {
      final plan = PkInstallPlan(
        installing: [
          PkPackage(
            info: PkInfo.installing,
            id: PkPackageId.parse('a;1;x;r'),
            summary: '',
          ),
        ],
        updating: [
          PkPackage(
            info: PkInfo.updating,
            id: PkPackageId.parse('b;2;x;r'),
            summary: '',
          ),
        ],
        removing: [],
        reinstalling: [],
        downgrading: [],
        obsoleting: [],
      );
      expect(plan.toString(), contains('+1'));
      expect(plan.toString(), contains('↑1'));
    });
  });

  group('planFromPackages', () {
    test('categorizes by PkInfo', () {
      final pkgs = [
        PkPackage(
          info: PkInfo.installing,
          id: PkPackageId.parse('a;1;x;r'),
          summary: '',
        ),
        PkPackage(
          info: PkInfo.removing,
          id: PkPackageId.parse('b;1;x;r'),
          summary: '',
        ),
        PkPackage(
          info: PkInfo.updating,
          id: PkPackageId.parse('c;2;x;r'),
          summary: '',
        ),
        PkPackage(
          info: PkInfo.obsoleting,
          id: PkPackageId.parse('d;1;x;r'),
          summary: '',
        ),
      ];
      final plan = planFromPackages(pkgs);
      expect(plan.installing, hasLength(1));
      expect(plan.removing, hasLength(1));
      expect(plan.updating, hasLength(1));
      expect(plan.obsoleting, hasLength(1));
    });

    test('categorizes reinstalling and downgrading', () {
      final pkgs = [
        PkPackage(
          info: PkInfo.reinstalling,
          id: PkPackageId.parse('a;1;x;r'),
          summary: '',
        ),
        PkPackage(
          info: PkInfo.downgrading,
          id: PkPackageId.parse('b;1;x;r'),
          summary: '',
        ),
      ];
      final plan = planFromPackages(pkgs);
      expect(plan.reinstalling, hasLength(1));
      expect(plan.downgrading, hasLength(1));
    });

    test('unknown info treated as install', () {
      final pkgs = [
        PkPackage(
          info: PkInfo.unknown,
          id: PkPackageId.parse('x;1;x;r'),
          summary: '',
        ),
      ];
      final plan = planFromPackages(pkgs);
      expect(plan.installing, hasLength(1));
    });
  });

  group('PkProgress', () {
    test('percentageKnown', () {
      const p = PkProgress(
        packageId: '',
        status: PkStatus.download,
        percentage: 50,
        isItem: false,
      );
      expect(p.percentageKnown, isTrue);
    });

    test('percentage unknown at 101', () {
      const p = PkProgress(
        packageId: '',
        status: PkStatus.running,
        percentage: 101,
        isItem: false,
      );
      expect(p.percentageKnown, isFalse);
    });
  });

  group('PkTransactionResult', () {
    test('success', () {
      const r = PkTransactionResult(exit: PkExit.success, runtimeMs: 100);
      expect(r.success, isTrue);
    });

    test('failure', () {
      const r = PkTransactionResult(exit: PkExit.failed, runtimeMs: 50);
      expect(r.success, isFalse);
    });
  });
}
