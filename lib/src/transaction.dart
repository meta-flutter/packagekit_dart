// transaction.dart

import 'dart:async';

import 'details.dart';
import 'enums.dart';
import 'package.dart';
import 'repo.dart';

/// Live transaction progress.
class PkProgress {
  /// The package identifier this progress applies to (empty for overall).
  final String packageId;

  /// Current transaction status.
  final PkStatus status;

  /// 0-100; 101 means unknown (backend hasn't reported yet).
  final int percentage;

  /// True if this is a per-item progress (ItemProgress signal) rather than
  /// the overall transaction progress (Progress signal).
  final bool isItem;

  /// Creates a [PkProgress] instance.
  const PkProgress({
    required this.packageId,
    required this.status,
    required this.percentage,
    required this.isItem,
  });

  /// Whether the backend has reported a numeric percentage.
  bool get percentageKnown => percentage <= 100;

  /// Human-readable progress string (e.g. "42%  [install]" or "[query]").
  String get progressLabel =>
      percentageKnown ? '$percentage%  [$status]' : '[${status.name}]';
}

/// Transaction completion result.
class PkTransactionResult {
  /// The exit code of the transaction.
  final PkExit exit;

  /// Wall-clock runtime in milliseconds.
  final int runtimeMs;

  /// Creates a [PkTransactionResult] instance.
  const PkTransactionResult({required this.exit, required this.runtimeMs});

  /// Whether the transaction completed successfully.
  bool get success => exit == PkExit.success;
}

/// The resolved install/remove/update plan from a simulate transaction.
///
/// Produced by [PkClient.simulateInstall], [PkClient.simulateRemove], and
/// [PkClient.simulateUpdate]. Contains the full set of packages that *would*
/// be changed if the corresponding real transaction were executed now.
///
/// **TOCTOU note:** the plan reflects the package database at the moment
/// simulate ran. The subsequent real transaction re-resolves from scratch
/// and may install different versions or additional/fewer dependencies if
/// the database changed in the interval.
class PkInstallPlan {
  /// Packages that will be newly installed.
  final List<PkPackage> installing;

  /// Packages that will be updated to a newer version.
  final List<PkPackage> updating;

  /// Packages that will be removed.
  final List<PkPackage> removing;

  /// Packages that will be reinstalled.
  final List<PkPackage> reinstalling;

  /// Packages that will be downgraded.
  final List<PkPackage> downgrading;

  /// Packages that will be obsoleted by other packages.
  final List<PkPackage> obsoleting;

  /// Creates a [PkInstallPlan] instance.
  const PkInstallPlan({
    required this.installing,
    required this.updating,
    required this.removing,
    required this.reinstalling,
    required this.downgrading,
    required this.obsoleting,
  });

  /// Raw package ID strings for all non-removal changes.
  List<String> get allIds => [
    ...installing,
    ...updating,
    ...reinstalling,
    ...downgrading,
  ].map((p) => p.id.raw).toList();

  /// Whether this plan contains no changes at all.
  bool get isEmpty =>
      installing.isEmpty &&
      updating.isEmpty &&
      removing.isEmpty &&
      reinstalling.isEmpty &&
      downgrading.isEmpty &&
      obsoleting.isEmpty;

  /// Total number of packages affected across all categories.
  int get changeCount =>
      installing.length +
      updating.length +
      removing.length +
      reinstalling.length +
      downgrading.length +
      obsoleting.length;

  @override
  String toString() =>
      'PkInstallPlan('
      '+${installing.length} ↑${updating.length} -${removing.length}'
      '${obsoleting.isNotEmpty ? " obs:${obsoleting.length}" : ""})';
}

/// Builds a [PkInstallPlan] from the Package signals emitted by a simulate
/// transaction.
PkInstallPlan planFromPackages(List<PkPackage> pkgs) {
  final installing = <PkPackage>[];
  final updating = <PkPackage>[];
  final removing = <PkPackage>[];
  final reinstalling = <PkPackage>[];
  final downgrading = <PkPackage>[];
  final obsoleting = <PkPackage>[];

  for (final p in pkgs) {
    switch (p.info) {
      case PkInfo.installing:
        installing.add(p);
      case PkInfo.updating:
        updating.add(p);
      case PkInfo.removing:
        removing.add(p);
      case PkInfo.reinstalling:
        reinstalling.add(p);
      case PkInfo.downgrading:
        downgrading.add(p);
      case PkInfo.obsoleting:
        obsoleting.add(p);
      default:
        installing.add(p);
    }
  }
  return PkInstallPlan(
    installing: installing,
    updating: updating,
    removing: removing,
    reinstalling: reinstalling,
    downgrading: downgrading,
    obsoleting: obsoleting,
  );
}

/// A live PackageKit transaction.
///
/// Streams emit D-Bus signals as they arrive from the daemon. Listen to
/// [packages], [details], [progress], etc. to observe the transaction.
/// Await [result] to get the final exit code, or call [cancel] to abort.
class PkTransaction {
  /// Stream of packages emitted by Package signals.
  final Stream<PkPackage> packages;

  /// Stream of detailed package info from Details signals.
  final Stream<PkPackageDetail> details;

  /// Stream of update details from UpdateDetail signals.
  final Stream<PkUpdateDetail> updateDetails;

  /// Stream of repository details from RepoDetail signals.
  final Stream<PkRepoDetail> repoDetails;

  /// Stream of file lists from Files signals.
  final Stream<PkFiles> files;

  /// Stream of progress updates from Progress / ItemProgress signals.
  final Stream<PkProgress> progress;

  /// Stream of daemon messages from Message signals.
  final Stream<PkMessage> messages;

  /// Stream of EULA requirements from EulaRequired signals.
  final Stream<PkEulaRequired> eulaRequired;

  /// Stream of repo signature requirements from RepoSignatureRequired signals.
  final Stream<PkRepoSigRequired> repoSigRequired;

  /// Stream of restart requirements from RequireRestart signals.
  final Stream<PkRequireRestart> requireRestart;

  /// Stream of error codes from ErrorCode signals.
  final Stream<PkErrorCode> errors;

  /// Completes with the transaction result, or throws [PkTransactionException].
  final Future<PkTransactionResult> result;

  /// Cancels the running transaction.
  final void Function() cancel;

  /// Creates a [PkTransaction] instance.
  const PkTransaction({
    required this.packages,
    required this.details,
    required this.updateDetails,
    required this.repoDetails,
    required this.files,
    required this.progress,
    required this.messages,
    required this.eulaRequired,
    required this.repoSigRequired,
    required this.requireRestart,
    required this.errors,
    required this.result,
    required this.cancel,
  });
}
