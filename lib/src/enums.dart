// enums.dart — typed wrappers over PackageKit uint32/uint64 enumerations.

/// Filter bitfield. Combine with | for multi-filter queries.
/// Mirrors PK_FILTER_ENUM_* from the D-Bus specification.
enum PkFilter {
  none(0),
  installed(1 << 2),
  notInstalled(1 << 3),
  development(1 << 4),
  notDevelopment(1 << 5),
  gui(1 << 6),
  notGui(1 << 7),
  free_(1 << 8),
  notFree(1 << 9),
  visible(1 << 10),
  notVisible(1 << 11),
  supported(1 << 12),
  notSupported(1 << 13),
  baseName(1 << 14),
  notBaseName(1 << 15),
  newest(1 << 16),
  notNewest(1 << 17),
  arch(1 << 18),
  notArch(1 << 19),
  source(1 << 20),
  notSource(1 << 21),
  collections(1 << 22),
  notCollections(1 << 23),
  application(1 << 24),
  notApplication(1 << 25),
  downloaded(1 << 26),
  notDownloaded(1 << 27);

  /// The underlying D-Bus bitfield value.
  final int value;
  const PkFilter(this.value);

  /// Combines multiple filters into a single bitfield using bitwise OR.
  static int combine(Iterable<PkFilter> filters) =>
      filters.fold(0, (acc, f) => acc | f.value);
}

/// Transaction flags (install/remove/update operations).
enum PkTransactionFlag {
  onlyTrusted(1 << 1),
  simulate(1 << 2),
  onlyDownload(1 << 3),
  allowReinstall(1 << 4),
  justReinstall(1 << 5),
  allowDowngrade(1 << 6);

  /// The underlying D-Bus bitfield value.
  final int value;
  const PkTransactionFlag(this.value);

  /// Combines multiple flags into a single bitfield using bitwise OR.
  static int combine(Iterable<PkTransactionFlag> flags) =>
      flags.fold(0, (acc, f) => acc | f.value);
}

/// Package info (state in a Package signal).
enum PkInfo {
  unknown(0),
  installed(1),
  available(2),
  low(3),
  enhancement(4),
  normal(5),
  bugfix(6),
  important(7),
  security(8),
  blocked(9),
  downloading(10),
  updating(11),
  installing(12),
  removing(13),
  cleanup(14),
  obsoleting(15),
  collectionInstalled(16),
  collectionAvailable(17),
  finished(18),
  reinstalling(19),
  downgrading(20),
  preparing(21),
  decompressing(22),
  untrusted(23),
  trusted(24),
  unavailable(25);

  /// The underlying PK_INFO_ENUM_* integer value.
  final int value;
  const PkInfo(this.value);

  /// Looks up the [PkInfo] for the given integer, falling back to [unknown].
  static PkInfo fromInt(int v) => PkInfo.values.firstWhere(
    (e) => e.value == v,
    orElse: () => PkInfo.unknown,
  );
}

/// Transaction status (StatusChanged signal).
enum PkStatus {
  unknown(0),
  wait(1),
  setup(2),
  running(3),
  query(4),
  info(5),
  remove(6),
  refreshCache(7),
  download(8),
  install(9),
  update(10),
  cleanup(11),
  obsolete(12),
  depResolve(13),
  sigCheck(14),
  testCommit(15),
  commit(16),
  request(17),
  finished(18),
  cancel(19),
  downloadRepository(20),
  downloadPackagelist(21),
  downloadFilelist(22),
  downloadChangelog(23),
  downloadGroup(24),
  downloadUpdateinfo(25),
  repackaging(26),
  loadingCache(27),
  scanApplications(28),
  generatePackageList(29),
  waitingForLock(30),
  waitingForAuth(31),
  scanProcessList(32),
  checkExecutableFiles(33),
  checkLibraries(34),
  copyFiles(35),
  runHook(36);

  /// The underlying PK_STATUS_ENUM_* integer value.
  final int value;
  const PkStatus(this.value);

  /// Looks up the [PkStatus] for the given integer, falling back to [unknown].
  static PkStatus fromInt(int v) => PkStatus.values.firstWhere(
    (e) => e.value == v,
    orElse: () => PkStatus.unknown,
  );
}

/// Exit code from the Finished signal.
enum PkExit {
  unknown(0),
  success(1),
  failed(2),
  cancelled(3),
  keyRequired(4),
  eulaRequired(5),
  killed(6),
  mediaRequired(7),
  needUntrusted(8),
  cancelledPriority(9),
  skipTransaction(10),
  repairRequired(11);

  /// The underlying PK_EXIT_ENUM_* integer value.
  final int value;
  const PkExit(this.value);

  /// Looks up the [PkExit] for the given integer, falling back to [unknown].
  static PkExit fromInt(int v) => PkExit.values.firstWhere(
    (e) => e.value == v,
    orElse: () => PkExit.unknown,
  );
}

/// Error codes from the ErrorCode signal.
enum PkError {
  unknown(0),
  oom(1),
  noNetwork(2),
  notSupported(3),
  internalError(4),
  gpgFailure(5),
  packageIdInvalid(6),
  packageNotInstalled(7),
  packageNotFound(8),
  packageAlreadyInstalled(9),
  packageDownloadFailed(10),
  groupNotFound(11),
  groupListInvalid(12),
  depResolutionFailed(13),
  filterInvalid(14),
  createThreadFailed(15),
  transactionError(16),
  transactionCancelled(17),
  noCache(18),
  repoNotFound(19),
  cannotRemoveSystemPackage(20),
  processKill(21),
  failedInitialization(22),
  failedFinalise(23),
  failedConfigParsing(24),
  cannotCancel(25),
  cannotGetLock(26),
  noPackagesToUpdate(27),
  cannotWriteRepoConfig(28),
  localInstallFailed(29),
  badGpgSignature(30),
  missingGpgSignature(31),
  cannotInstallSourcePackage(32),
  repoConfigurationError(33),
  noLicenseAgreement(34),
  fileConflicts(35),
  packageConflicts(36),
  repoNotAvailable(37),
  invalidPackageFile(38),
  packageInstallBlocked(39),
  packageCorrupt(40),
  allPackagesAlreadyInstalled(41),
  fileNotFound(42),
  noMoreMirrorsToTry(43),
  noDistroUpgradeData(44),
  incompatibleArchitecture(45),
  noSpaceOnDevice(46),
  mediaChangeRequired(47),
  notAuthorized(48),
  updateNotFound(49),
  cannotInstallRepoUnsigned(50),
  cannotUpdateRepoUnsigned(51),
  cannotGetFilelist(52),
  cannotGetRequires(53),
  cannotDisableRepository(54),
  restrictedDownload(55),
  packageFailedToConfigure(56),
  packageFailedToBuild(57),
  packageFailedToInstall(58),
  packageFailedToRemove(59),
  updateFailedDueToRunningProcess(60),
  packageDatabaseChanged(61),
  providedBySystem(62),
  installRootInvalid(63),
  cannotFetchSources(64),
  cancelledRemoveSysReq(65),
  unfinishedTransaction(66),
  lockRequired(67),
  repoAlreadySet(68);

  /// The underlying PK_ERROR_ENUM_* integer value.
  final int value;
  const PkError(this.value);

  /// Looks up the [PkError] for the given integer, falling back to [unknown].
  static PkError fromInt(int v) => PkError.values.firstWhere(
    (e) => e.value == v,
    orElse: () => PkError.unknown,
  );
}
