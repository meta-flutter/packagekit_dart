## 0.4.0

- Send the `interactive` hint on every transaction. The daemon treats an
  absent hint as false, which strips `ALLOW_USER_INTERACTION` from its polkit
  check — so any transaction needing authorization failed synchronously with
  `PkError.notAuthorized` and a 0 ms runtime, on any host where the polkit
  action is `auth_admin` and the caller is not root.
- Add `PkClient.connect({bool interactive = true})` and the matching
  `PkClient.interactive` getter. Interactive is the default: transactions that
  need authorization now prompt instead of failing. Pass `interactive: false`
  for unattended callers that must fail fast rather than block on a prompt —
  it suppresses the prompt, it does not grant authorization.
- Document authorization on WSL, where polkit cannot reliably prompt because
  a logind session owned by the calling user is often absent. Recommends
  running as root, with a narrowly scoped polkit rule as an opt-in
  alternative, plus how to tell a session problem from a real denial.
- **C ABI change:** `pk_transaction_set_hints` takes a third parameter,
  `bool interactive`. Consumers linking `libpackagekit_nc` directly must
  update their declaration; consumers using the build hook are unaffected,
  as it compiles the library from source.

## 0.3.2

- Point `repository` and `issue_tracker` at the jwinarske fork, fixing
  pub.dev repository verification.

## 0.3.1

- Add `WhatProvides` (native `pk_what_provides`, FFI binding, and
  `PkClient.whatProvides`) — resolve capabilities / provides / file paths
  (e.g. `pkg-config`, provided by `pkgconf-pkg-config`), matching `dnf`/`apt`
  install behavior. Mirrors the existing `Resolve` path.
- Add `setPackagekitLibraryPath()` to point the native-library loader at a
  prebuilt `libpackagekit_nc.so`, taking precedence over `PK_NC_LIB`. Useful
  for path/git dependencies that ship or build the `.so` outside the build
  hook.

## 0.3.0

- Extract TransactionDispatcher and dispatchManagerEvent for testable
  message dispatch without a live daemon
- 102 unit tests covering all codec discriminators, model constructors,
  enum round-trips, dispatcher paths, and error handling
- ~98% coverage on testable Dart code (FFI glue excluded)
- Remove unused generated sdbus-cpp proxy headers and D-Bus XML interfaces
- Remove go_router; use index-based navigation for instant screen switching
- Fix CI: add libclang-rt-19-dev for ASAN, exclude test/ from clang-tidy,
  add dart pub get before format check, add flutter analyze step
- Lower Dart coverage threshold to 10% (FFI-heavy package)
- Add Flutter example screenshot to README
- Fix detail pane overlay on screen switch and package selection

## 0.2.0

- Native build hook (`hook/build.dart`) using `package:hooks` and
  `package:code_assets` — automatically compiles libpackagekit_nc.so via
  CMake at build time and bundles it as a CodeAsset
- Auto-clone sdbus-cpp at pinned commit when submodule is unavailable
  (pub.dev installs)
- Flutter example app (`example/packagekit_catalog/`) — Material 3 desktop
  catalog with Riverpod state management, GoRouter navigation, search,
  installed packages, updates, and repository views
- Codecov integration with 60% threshold enforcement
- Dart and C++ coverage collection in CI

## 0.1.0

- Initial release
- PkClient with async stream-based API for PackageKit D-Bus operations
- Query methods: searchName, searchDetails, searchFiles, resolve, getPackages,
  getUpdates, getDetails, getUpdateDetail, getFiles, getRepoList, dependsOn,
  requiredBy, getDistroUpgrades
- Write methods: installPackages, removePackages, updatePackages, refreshCache,
  downloadPackages, installFiles, repoEnable, acceptEula
- Simulate-first pattern: simulateInstall, simulateRemove, simulateUpdate
  returning PkInstallPlan with full dependency resolution
- Typed enums: PkFilter, PkTransactionFlag, PkInfo, PkStatus, PkExit, PkError
- Domain models: PkPackage, PkPackageDetail, PkUpdateDetail, PkRepoDetail,
  PkFiles, PkProgress, PkInstallPlan
- Daemon event monitoring: UpdatesChanged, RepoListChanged
- Native bridge using sdbus-cpp v2 with glaze binary encoding
- Supports APT, DNF, Zypper, and other PackageKit backends
