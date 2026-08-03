// packagekit_client.dart
//
// PkClient is the top-level API entry point.

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'enums.dart';
import 'exceptions.dart';
import 'ffi/bindings.dart';
import 'ffi/types.dart';
import 'internal/dispatcher.dart';
import 'package.dart';
import 'transaction.dart';

/// Daemon-level events from the manager.
sealed class PkDaemonEvent {}

/// Emitted when the daemon's properties change (backend info, version, etc.).
class PkPropsEvent extends PkDaemonEvent {
  /// The updated property snapshot.
  final PkManagerProps props;

  /// Creates a [PkPropsEvent] with the given [props].
  PkPropsEvent(this.props);
}

/// Emitted when the available-updates list changes.
class PkUpdatesChangedEvent extends PkDaemonEvent {}

/// Emitted when the repository list changes.
class PkRepoListChangedEvent extends PkDaemonEvent {}

/// Emitted when the network state changes.
class PkNetworkStateChangedEvent extends PkDaemonEvent {
  /// New network state (PK_NETWORK_ENUM_*).
  final int state;

  /// Creates a [PkNetworkStateChangedEvent] with the given [state].
  PkNetworkStateChangedEvent(this.state);
}

/// Top-level API for interacting with the PackageKit daemon over D-Bus.
///
/// Call [PkClient.connect] to establish a connection, then use query methods
/// like [searchName] and write methods like [installPackages].
class PkClient {
  final Object _managerHandle;
  final ReceivePort _eventsPort;
  final bool _interactive;
  final StreamController<PkDaemonEvent> _daemonEvents =
      StreamController.broadcast();

  PkClient._(this._managerHandle, this._eventsPort, this._interactive) {
    _eventsPort.listen(_onManagerEvent);
  }

  static bool _initialized = false;

  /// Whether transactions from this client may prompt for authorization.
  bool get interactive => _interactive;

  /// Connect to the PackageKit daemon on the system bus.
  ///
  /// When [interactive] is true (the default), transactions that require
  /// authorization ask polkit to prompt the user. When false, such
  /// transactions fail immediately with [PkError.notAuthorized]; the caller
  /// must already be authorized, either as root or by a polkit rule.
  ///
  /// Non-interactive is not an authorization mechanism — it suppresses the
  /// prompt, it does not grant anything.
  static Future<PkClient> connect({bool interactive = true}) async {
    if (!_initialized) {
      PkBindings.init(NativeApi.initializeApiDLData);
      _initialized = true;
    }
    final port = ReceivePort('packagekit.manager');
    final handle = PkBindings.managerCreate(port.sendPort.nativePort);
    if ((handle as Pointer).address == 0) {
      port.close();
      throw const PkServiceUnavailableException(
          'Failed to connect to org.freedesktop.PackageKit on the system bus.');
    }
    final client = PkClient._(handle, port, interactive);
    await client._loadProperties();
    return client;
  }

  // ── Daemon property access ──────────────────────────────────────────────

  PkManagerProps? _props;

  /// The most recently received daemon property snapshot, or null if not yet loaded.
  PkManagerProps? get properties => _props;

  /// Broadcast stream of daemon-level events (property changes, updates changed, etc.).
  Stream<PkDaemonEvent> get daemonEvents => _daemonEvents.stream;

  // ── Query operations ────────────────────────────────────────────────────

  /// Searches packages by name substring.
  PkTransaction searchName(
    String query, {
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery(
          (h) => PkBindings.searchName(h, PkFilter.combine(filters), [query]));

  /// Searches packages by description substring.
  PkTransaction searchDetails(
    String query, {
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery((h) =>
          PkBindings.searchDetails(h, PkFilter.combine(filters), [query]));

  /// Searches for packages that own the given file [path].
  PkTransaction searchFiles(
    String path, {
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery(
          (h) => PkBindings.searchFiles(h, PkFilter.combine(filters), [path]));

  /// Lists all packages matching the given [filters].
  PkTransaction getPackages({
    List<PkFilter> filters = const [PkFilter.installed],
  }) =>
      _startQuery((h) => PkBindings.getPackages(h, PkFilter.combine(filters)));

  /// Lists available updates matching the given [filters].
  PkTransaction getUpdates({
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery((h) => PkBindings.getUpdates(h, PkFilter.combine(filters)));

  /// Resolves package [names] to full package IDs.
  PkTransaction resolve(
    List<String> names, {
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery(
          (h) => PkBindings.resolve(h, PkFilter.combine(filters), names));

  /// Find packages that provide the given capabilities/[values] (rpm/deb
  /// `Provides:`, file paths, virtual names). Unlike [resolve], which matches
  /// package names only, this resolves provides such as `pkg-config`
  /// (provided by `pkgconf-pkg-config`) or `libjpeg-devel`
  /// (provided by `libjpeg-turbo-devel`).
  PkTransaction whatProvides(
    List<String> values, {
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery(
          (h) => PkBindings.whatProvides(h, PkFilter.combine(filters), values));

  /// Retrieves detailed metadata for the given [packageIds].
  PkTransaction getDetails(List<String> packageIds) =>
      _startQuery((h) => PkBindings.getDetails(h, packageIds));

  /// Retrieves update details for the given [packageIds].
  PkTransaction getUpdateDetail(List<String> packageIds) =>
      _startQuery((h) => PkBindings.getUpdateDetail(h, packageIds));

  /// Retrieves file lists for the given [packageIds].
  PkTransaction getFiles(List<String> packageIds) =>
      _startQuery((h) => PkBindings.getFiles(h, packageIds));

  /// Lists configured repositories.
  PkTransaction getRepoList({
    List<PkFilter> filters = const [PkFilter.none],
  }) =>
      _startQuery((h) => PkBindings.getRepoList(h, PkFilter.combine(filters)));

  /// Lists packages that the given [packageIds] depend on.
  PkTransaction dependsOn(
    List<String> packageIds, {
    List<PkFilter> filters = const [PkFilter.none],
    bool recursive = false,
  }) =>
      _startQuery((h) => PkBindings.dependsOn(
          h, PkFilter.combine(filters), packageIds, recursive));

  /// Lists packages that require the given [packageIds].
  PkTransaction requiredBy(
    List<String> packageIds, {
    List<PkFilter> filters = const [PkFilter.none],
    bool recursive = false,
  }) =>
      _startQuery((h) => PkBindings.requiredBy(
          h, PkFilter.combine(filters), packageIds, recursive));

  /// Lists available distribution upgrades.
  PkTransaction getDistroUpgrades() =>
      _startQuery((h) => PkBindings.getDistroUpgrades(h));

  // ── Dependency resolution ───────────────────────────────────────────────

  /// Simulates installing the given [packageIds] and returns the resolved plan.
  Future<PkInstallPlan> simulateInstall(
    List<String> packageIds, {
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _collectPlan(_startQuery((h) => PkBindings.installPackages(
          h,
          PkTransactionFlag.combine([...flags, PkTransactionFlag.simulate]),
          packageIds)));

  /// Simulates removing the given [packageIds] and returns the resolved plan.
  Future<PkInstallPlan> simulateRemove(
    List<String> packageIds, {
    bool allowDeps = false,
    bool autoremove = false,
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _collectPlan(_startQuery((h) => PkBindings.removePackages(
          h,
          PkTransactionFlag.combine([...flags, PkTransactionFlag.simulate]),
          packageIds,
          allowDeps,
          autoremove)));

  /// Simulates updating the given [packageIds] and returns the resolved plan.
  Future<PkInstallPlan> simulateUpdate(
    List<String> packageIds, {
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _collectPlan(_startQuery((h) => PkBindings.updatePackages(
          h,
          PkTransactionFlag.combine([...flags, PkTransactionFlag.simulate]),
          packageIds)));

  Future<PkInstallPlan> _collectPlan(PkTransaction tx) async {
    final pkgs = <PkPackage>[];
    await for (final pkg in tx.packages) {
      pkgs.add(pkg);
    }
    await tx.result;
    return planFromPackages(pkgs);
  }

  // ── Write operations ────────────────────────────────────────────────────

  /// Installs the given [packageIds].
  PkTransaction installPackages(
    List<String> packageIds, {
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _startQuery((h) => PkBindings.installPackages(
          h, PkTransactionFlag.combine(flags), packageIds));

  /// Removes the given [packageIds].
  PkTransaction removePackages(
    List<String> packageIds, {
    bool allowDeps = false,
    bool autoremove = false,
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _startQuery((h) => PkBindings.removePackages(h,
          PkTransactionFlag.combine(flags), packageIds, allowDeps, autoremove));

  /// Updates the given [packageIds] to the latest available versions.
  PkTransaction updatePackages(
    List<String> packageIds, {
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _startQuery((h) => PkBindings.updatePackages(
          h, PkTransactionFlag.combine(flags), packageIds));

  /// Refreshes the package cache. Set [force] to bypass the daemon's freshness check.
  PkTransaction refreshCache({bool force = false}) =>
      _startQuery((h) => PkBindings.refreshCache(h, force));

  /// Installs local package files at the given [paths].
  PkTransaction installFiles(
    List<String> paths, {
    List<PkTransactionFlag> flags = const [PkTransactionFlag.onlyTrusted],
  }) =>
      _startQuery((h) =>
          PkBindings.installFiles(h, PkTransactionFlag.combine(flags), paths));

  /// Downloads the given [packageIds] without installing them.
  PkTransaction downloadPackages(
    List<String> packageIds, {
    bool storeInCache = true,
  }) =>
      _startQuery(
          (h) => PkBindings.downloadPackages(h, storeInCache, packageIds));

  /// Enables or disables the repository identified by [repoId].
  PkTransaction repoEnable(String repoId, {required bool enabled}) =>
      _startQuery((h) => PkBindings.repoEnable(h, repoId, enabled));

  /// Accepts the EULA identified by [eulaId].
  PkTransaction acceptEula(String eulaId) =>
      _startQuery((h) => PkBindings.acceptEula(h, eulaId));

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Disconnects from the PackageKit daemon and releases resources.
  Future<void> close() async {
    PkBindings.managerDestroy(_managerHandle);
    _eventsPort.close();
    await _daemonEvents.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _loadProperties() async {
    final c = Completer<void>();
    _daemonEvents.stream.where((e) => e is PkPropsEvent).first.then((_) {
      if (!c.isCompleted) c.complete();
    });
    PkBindings.managerReadProperties(_managerHandle);
    await c.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (!c.isCompleted) c.complete();
      },
    );
  }

  PkTransaction _startQuery(void Function(Object txHandle) invoke) {
    final port = ReceivePort('packagekit.tx');
    final d = TransactionDispatcher();

    final txHandle =
        PkBindings.transactionCreate(_managerHandle, port.sendPort.nativePort);
    final validHandle = (txHandle as Pointer).address != 0;

    void closeAll() {
      d.close();
      port.close();
      if (validHandle) {
        PkBindings.transactionDestroy(txHandle);
      }
    }

    port.listen((dynamic msg) {
      if (msg is! Uint8List) return;
      d.dispatch(msg);
      if (d.finished) closeAll();
    });

    if (!validHandle) {
      closeAll();
      d.done.completeError(const PkServiceUnavailableException(
          'Failed to create PackageKit transaction.'));
    } else {
      PkBindings.transactionSetHints(txHandle, 'en_US.UTF-8', _interactive);
      invoke(txHandle);
    }

    return PkTransaction(
      packages: d.packages.stream,
      details: d.details.stream,
      updateDetails: d.updateDetails.stream,
      repoDetails: d.repoDetails.stream,
      files: d.files.stream,
      progress: d.progress.stream,
      messages: d.messages.stream,
      eulaRequired: d.eulaRequired.stream,
      repoSigRequired: d.repoSigRequired.stream,
      requireRestart: d.requireRestart.stream,
      errors: d.errors.stream,
      result: d.done.future,
      cancel: () {
        if (!d.finished) PkBindings.transactionCancel(txHandle);
      },
    );
  }

  void _onManagerEvent(dynamic msg) {
    final event = dispatchManagerEvent(msg);
    if (event == null) return;
    switch (event) {
      case ManagerPropsEvent(:final props):
        _props = props;
        _daemonEvents.add(PkPropsEvent(props));
      case ManagerUpdatesChangedEvent():
        _daemonEvents.add(PkUpdatesChangedEvent());
      case ManagerRepoListChangedEvent():
        _daemonEvents.add(PkRepoListChangedEvent());
      case ManagerNetworkStateChangedEvent(:final state):
        _daemonEvents.add(PkNetworkStateChangedEvent(state));
    }
  }
}
