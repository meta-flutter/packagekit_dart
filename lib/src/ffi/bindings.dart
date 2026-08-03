// bindings.dart — lookupFunction wrappers for pk_bridge.h C ABI.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../internal/library_loader.dart';

/// FFI bindings to the native packagekit_nc shared library.
class PkBindings {
  PkBindings._();

  static final DynamicLibrary _lib = loadPackagekitNc();

  static final _init = _lib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pk_bridge_init');

  static void init(Pointer<Void> dartApiDlData) => _init(dartApiDlData);

  // ── Manager ────────────────────────────────────────────────────────────────

  static final _managerCreate = _lib.lookupFunction<
      Pointer<Void> Function(Int64),
      Pointer<Void> Function(int)>('pk_manager_create');

  static final _managerDestroy = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pk_manager_destroy');

  static final _managerReadProperties = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pk_manager_read_properties');

  static Pointer<Void> managerCreate(int eventsPort) =>
      _managerCreate(eventsPort);
  static void managerDestroy(Object handle) =>
      _managerDestroy(handle as Pointer<Void>);
  static void managerReadProperties(Object handle) =>
      _managerReadProperties(handle as Pointer<Void>);

  // ── Transaction ────────────────────────────────────────────────────────────

  static final _txCreate = _lib.lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Int64),
      Pointer<Void> Function(Pointer<Void>, int)>('pk_transaction_create');

  static final _txDestroy = _lib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pk_transaction_destroy');

  static final _txSetHints = _lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Utf8>, Bool),
      void Function(
          Pointer<Void>, Pointer<Utf8>, bool)>('pk_transaction_set_hints');

  static Pointer<Void> transactionCreate(Object manager, int txPort) =>
      _txCreate(manager as Pointer<Void>, txPort);

  static void transactionDestroy(Object handle) =>
      _txDestroy(handle as Pointer<Void>);

  static void transactionSetHints(
      Object handle, String locale, bool interactive) {
    final p = locale.toNativeUtf8();
    _txSetHints(handle as Pointer<Void>, p, interactive);
    calloc.free(p);
  }

  static void transactionCancel(Object handle) =>
      _cancel(handle as Pointer<Void>);

  // ── Query methods ──────────────────────────────────────────────────────────

  static void searchName(Object h, int filter, List<String> values) =>
      _callStringList(_searchName, h, filter, values);
  static void searchDetails(Object h, int filter, List<String> values) =>
      _callStringList(_searchDetails, h, filter, values);
  static void searchFiles(Object h, int filter, List<String> values) =>
      _callStringList(_searchFiles, h, filter, values);
  static void getPackages(Object h, int filter) =>
      _getPackages(h as Pointer<Void>, filter);
  static void getUpdates(Object h, int filter) =>
      _getUpdates(h as Pointer<Void>, filter);
  static void resolve(Object h, int filter, List<String> ids) =>
      _callStringList(_resolve, h, filter, ids);
  static void whatProvides(Object h, int filter, List<String> values) =>
      _callStringList(_whatProvides, h, filter, values);
  static void getDetails(Object h, List<String> ids) =>
      _callIds(_getDetails, h, ids);
  static void getUpdateDetail(Object h, List<String> ids) =>
      _callIds(_getUpdateDetail, h, ids);
  static void getFiles(Object h, List<String> ids) =>
      _callIds(_getFiles, h, ids);
  static void getRepoList(Object h, int filter) =>
      _getRepoList(h as Pointer<Void>, filter);
  static void getDistroUpgrades(Object h) =>
      _getDistroUpgrades(h as Pointer<Void>);

  static void dependsOn(
      Object h, int filter, List<String> ids, bool recursive) {
    final arr = _allocStringArray(ids);
    _dependsOn(h as Pointer<Void>, filter, arr, ids.length, recursive);
    _freeStringArray(arr, ids.length);
  }

  static void requiredBy(
      Object h, int filter, List<String> ids, bool recursive) {
    final arr = _allocStringArray(ids);
    _requiredBy(h as Pointer<Void>, filter, arr, ids.length, recursive);
    _freeStringArray(arr, ids.length);
  }

  // ── Write methods ──────────────────────────────────────────────────────────

  static void installPackages(Object h, int flags, List<String> ids) {
    final arr = _allocStringArray(ids);
    _installPackages(h as Pointer<Void>, flags, arr, ids.length);
    _freeStringArray(arr, ids.length);
  }

  static void removePackages(
      Object h, int flags, List<String> ids, bool allowDeps, bool autoremove) {
    final arr = _allocStringArray(ids);
    _removePackages(
        h as Pointer<Void>, flags, arr, ids.length, allowDeps, autoremove);
    _freeStringArray(arr, ids.length);
  }

  static void updatePackages(Object h, int flags, List<String> ids) {
    final arr = _allocStringArray(ids);
    _updatePackages(h as Pointer<Void>, flags, arr, ids.length);
    _freeStringArray(arr, ids.length);
  }

  static void refreshCache(Object h, bool force) =>
      _refreshCache(h as Pointer<Void>, force);

  static void downloadPackages(Object h, bool storeInCache, List<String> ids) {
    final arr = _allocStringArray(ids);
    _downloadPackages(h as Pointer<Void>, storeInCache, arr, ids.length);
    _freeStringArray(arr, ids.length);
  }

  static void installFiles(Object h, int flags, List<String> paths) {
    final arr = _allocStringArray(paths);
    _installFiles(h as Pointer<Void>, flags, arr, paths.length);
    _freeStringArray(arr, paths.length);
  }

  static void repoEnable(Object h, String repoId, bool enabled) {
    final p = repoId.toNativeUtf8();
    _repoEnable(h as Pointer<Void>, p, enabled);
    calloc.free(p);
  }

  static void acceptEula(Object h, String eulaId) {
    final p = eulaId.toNativeUtf8();
    _acceptEula(h as Pointer<Void>, p);
    calloc.free(p);
  }

  // ── Native function lookups ────────────────────────────────────────────────

  static final _searchName = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, int, Pointer<Pointer<Utf8>>, int)>('pk_search_name');

  static final _searchDetails = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>,
          int)>('pk_search_details');

  static final _searchFiles = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, int, Pointer<Pointer<Utf8>>, int)>('pk_search_files');

  static final _getPackages = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64),
      void Function(Pointer<Void>, int)>('pk_get_packages');

  static final _getUpdates = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64),
      void Function(Pointer<Void>, int)>('pk_get_updates');

  static final _resolve = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, int, Pointer<Pointer<Utf8>>, int)>('pk_resolve');

  static final _whatProvides = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, int, Pointer<Pointer<Utf8>>, int)>('pk_what_provides');

  static final _getDetails = _lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, Pointer<Pointer<Utf8>>, int)>('pk_get_details');

  static final _getUpdateDetail = _lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, Pointer<Pointer<Utf8>>, int)>('pk_get_update_detail');

  static final _getFiles = _lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, Pointer<Pointer<Utf8>>, int)>('pk_get_files');

  static final _getRepoList = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64),
      void Function(Pointer<Void>, int)>('pk_get_repo_list');

  static final _dependsOn = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32, Bool),
      void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>, int,
          bool)>('pk_depends_on');

  static final _requiredBy = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32, Bool),
      void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>, int,
          bool)>('pk_required_by');

  static final _getDistroUpgrades = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pk_get_distro_upgrades');

  static final _installPackages = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>,
          int)>('pk_install_packages');

  static final _removePackages = _lib.lookupFunction<
      Void Function(
          Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32, Bool, Bool),
      void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>, int, bool,
          bool)>('pk_remove_packages');

  static final _updatePackages = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>,
          int)>('pk_update_packages');

  static final _refreshCache = _lib.lookupFunction<
      Void Function(Pointer<Void>, Bool),
      void Function(Pointer<Void>, bool)>('pk_refresh_cache');

  static final _downloadPackages = _lib.lookupFunction<
      Void Function(Pointer<Void>, Bool, Pointer<Pointer<Utf8>>, Int32),
      void Function(Pointer<Void>, bool, Pointer<Pointer<Utf8>>,
          int)>('pk_download_packages');

  static final _installFiles = _lib.lookupFunction<
      Void Function(Pointer<Void>, Uint64, Pointer<Pointer<Utf8>>, Int32),
      void Function(
          Pointer<Void>, int, Pointer<Pointer<Utf8>>, int)>('pk_install_files');

  static final _repoEnable = _lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Utf8>, Bool),
      void Function(Pointer<Void>, Pointer<Utf8>, bool)>('pk_repo_enable');

  static final _acceptEula = _lib.lookupFunction<
      Void Function(Pointer<Void>, Pointer<Utf8>),
      void Function(Pointer<Void>, Pointer<Utf8>)>('pk_accept_eula');

  static final _cancel = _lib.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('pk_cancel');

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Pointer<Pointer<Utf8>> _allocStringArray(List<String> strings) {
    final arr = calloc<Pointer<Utf8>>(strings.length);
    for (var i = 0; i < strings.length; i++) {
      arr[i] = strings[i].toNativeUtf8();
    }
    return arr;
  }

  static void _freeStringArray(Pointer<Pointer<Utf8>> arr, int count) {
    for (var i = 0; i < count; i++) {
      calloc.free(arr[i]);
    }
    calloc.free(arr);
  }

  static void _callStringList(
    void Function(Pointer<Void>, int, Pointer<Pointer<Utf8>>, int) fn,
    Object h,
    int filter,
    List<String> values,
  ) {
    final arr = _allocStringArray(values);
    fn(h as Pointer<Void>, filter, arr, values.length);
    _freeStringArray(arr, values.length);
  }

  static void _callIds(
    void Function(Pointer<Void>, Pointer<Pointer<Utf8>>, int) fn,
    Object h,
    List<String> ids,
  ) {
    final arr = _allocStringArray(ids);
    fn(h as Pointer<Void>, arr, ids.length);
    _freeStringArray(arr, ids.length);
  }
}
