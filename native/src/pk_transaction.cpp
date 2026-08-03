// pk_transaction.cpp — PkTransactionBridge implementation.
//
// Wraps a single PackageKit transaction object path. Registers all signal
// handlers on construction so no signal is missed after invoking a method.
// Every signal handler glaze-encodes its payload with a discriminator byte
// and posts it to the Dart port via Dart_PostCObject_DL.

#include "pk_transaction.h"

#include <cstring>
#include <map>
#include <utility>

static constexpr const char* PK_TX_IFACE = "org.freedesktop.PackageKit.Transaction";

// Discriminator bytes (see pk_types.h).
static constexpr uint8_t kPackage = 0x01;
static constexpr uint8_t kProgress = 0x02;
static constexpr uint8_t kDetails = 0x03;
static constexpr uint8_t kUpdateDetail = 0x04;
static constexpr uint8_t kRepoDetail = 0x05;
static constexpr uint8_t kFiles = 0x06;
static constexpr uint8_t kErrorCode = 0x07;
static constexpr uint8_t kMessage = 0x08;
static constexpr uint8_t kEulaRequired = 0x09;
static constexpr uint8_t kRepoSigReq = 0x0A;
static constexpr uint8_t kRequireRestart = 0x0B;
static constexpr uint8_t kFinished = 0x20;
static constexpr uint8_t kSentinel = 0xFF;

// ── Constructor / Destructor ─────────────────────────────────────────────────

PkTransactionBridge::PkTransactionBridge(sdbus::IConnection& conn, sdbus::ObjectPath object_path,
                                         Dart_Port dart_port)
    : path_(std::move(object_path)), port_(dart_port) {
    proxy_ = sdbus::createProxy(conn, sdbus::ServiceName{"org.freedesktop.PackageKit"}, path_);

    // Register all signal handlers before any method call.
    proxy_->uponSignal("Package")
        .onInterface(PK_TX_IFACE)
        .call([this](const uint32_t& info, const std::string& pkg_id, const std::string& summary) {
            onPackage(info, pkg_id, summary);
        });

    // Batch variant (emitted when supports-plural-signals hint is set).
    proxy_->uponSignal("Packages")
        .onInterface(PK_TX_IFACE)
        .call(
            [this](const std::vector<sdbus::Struct<uint32_t, std::string, std::string>>& packages) {
                for (const auto& p : packages) {
                    onPackage(std::get<0>(p), std::get<1>(p), std::get<2>(p));
                }
            });

    proxy_->uponSignal("Progress")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& pkg_id, const uint32_t& status, const uint32_t& pct) {
            onProgress(pkg_id, status, pct);
        });

    proxy_->uponSignal("ItemProgress")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& id, const uint32_t& status, const uint32_t& pct) {
            onItemProgress(id, status, pct);
        });

    proxy_->uponSignal("StatusChanged")
        .onInterface(PK_TX_IFACE)
        .call([this](const uint32_t& status) { onStatusChanged(status); });

    proxy_->uponSignal("Details")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::map<std::string, sdbus::Variant>& data) { onDetails(data); });

    proxy_->uponSignal("UpdateDetail")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& pkg_id, const std::vector<std::string>& updates,
                     const std::vector<std::string>& obsoletes,
                     const std::vector<std::string>& vendor_urls,
                     const std::vector<std::string>& bugzilla_urls,
                     const std::vector<std::string>& cve_urls, const uint32_t& restart,
                     const std::string& update_text, const std::string& changelog,
                     const uint32_t& state, const std::string& issued, const std::string& updated) {
            onUpdateDetail(pkg_id, updates, obsoletes, vendor_urls, bugzilla_urls, cve_urls,
                           restart, update_text, changelog, state, issued, updated);
        });

    proxy_->uponSignal("RepoDetail")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& repo_id, const std::string& desc, const bool& enabled) {
            onRepoDetail(repo_id, desc, enabled);
        });

    proxy_->uponSignal("RepoSignatureRequired")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& pkg_id, const std::string& repo_name,
                     const std::string& key_url, const std::string& key_userid,
                     const std::string& key_id, const std::string& fingerprint,
                     const std::string& timestamp, const uint32_t& type) {
            onRepoSignatureRequired(pkg_id, repo_name, key_url, key_userid, key_id, fingerprint,
                                    timestamp, type);
        });

    proxy_->uponSignal("EulaRequired")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& eula_id, const std::string& pkg_id,
                     const std::string& vendor, const std::string& license) {
            onEulaRequired(eula_id, pkg_id, vendor, license);
        });

    proxy_->uponSignal("Files")
        .onInterface(PK_TX_IFACE)
        .call([this](const std::string& pkg_id, const std::vector<std::string>& files) {
            onFiles(pkg_id, files);
        });

    proxy_->uponSignal("ErrorCode")
        .onInterface(PK_TX_IFACE)
        .call([this](const uint32_t& code, const std::string& details) {
            onErrorCode(code, details);
        });

    proxy_->uponSignal("RequireRestart")
        .onInterface(PK_TX_IFACE)
        .call([this](const uint32_t& type, const std::string& pkg_id) {
            onRequireRestart(type, pkg_id);
        });

    proxy_->uponSignal("Message")
        .onInterface(PK_TX_IFACE)
        .call(
            [this](const uint32_t& type, const std::string& details) { onMessage(type, details); });

    proxy_->uponSignal("Finished")
        .onInterface(PK_TX_IFACE)
        .call([this](const uint32_t& exit_code, const uint32_t& runtime) {
            onFinished(exit_code, runtime);
        });

    proxy_->uponSignal("Destroy").onInterface(PK_TX_IFACE).call([this]() { onDestroy(); });
}

PkTransactionBridge::~PkTransactionBridge() {
    // Unregister the proxy before destruction to ensure no signal handler
    // fires on the event loop thread after member data is freed.
    proxy_->unregister();
}

// ── SetHints ─────────────────────────────────────────────────────────────────

std::vector<std::string> PkTransactionBridge::buildHints(const std::string& locale,
                                                         bool interactive) {
    // The daemon defaults interactive to FALSE when the hint is absent, which
    // strips ALLOW_USER_INTERACTION from its polkit check and makes any
    // transaction needing auth fail synchronously. Always send it explicitly.
    return {
        "locale=" + locale,
        "background=false",
        "supports-plural-signals=true",
        std::string("interactive=") + (interactive ? "true" : "false"),
    };
}

void PkTransactionBridge::setHints(const std::string& locale, bool interactive) {
    proxy_->callMethod("SetHints")
        .onInterface(PK_TX_IFACE)
        .withArguments(buildHints(locale, interactive));
}

// ── Query methods ────────────────────────────────────────────────────────────

void PkTransactionBridge::searchName(uint64_t filter, const std::vector<std::string>& values) {
    proxy_->callMethod("SearchNames").onInterface(PK_TX_IFACE).withArguments(filter, values);
}

void PkTransactionBridge::searchDetails(uint64_t filter, const std::vector<std::string>& values) {
    proxy_->callMethod("SearchDetails").onInterface(PK_TX_IFACE).withArguments(filter, values);
}

void PkTransactionBridge::searchFiles(uint64_t filter, const std::vector<std::string>& values) {
    proxy_->callMethod("SearchFiles").onInterface(PK_TX_IFACE).withArguments(filter, values);
}

void PkTransactionBridge::searchGroups(uint64_t filter, const std::vector<std::string>& values) {
    proxy_->callMethod("SearchGroups").onInterface(PK_TX_IFACE).withArguments(filter, values);
}

void PkTransactionBridge::getPackages(uint64_t filter) {
    proxy_->callMethod("GetPackages").onInterface(PK_TX_IFACE).withArguments(filter);
}

void PkTransactionBridge::getUpdates(uint64_t filter) {
    proxy_->callMethod("GetUpdates").onInterface(PK_TX_IFACE).withArguments(filter);
}

void PkTransactionBridge::resolve(uint64_t filter, const std::vector<std::string>& package_ids) {
    proxy_->callMethod("Resolve").onInterface(PK_TX_IFACE).withArguments(filter, package_ids);
}

void PkTransactionBridge::whatProvides(uint64_t filter, const std::vector<std::string>& values) {
    proxy_->callMethod("WhatProvides").onInterface(PK_TX_IFACE).withArguments(filter, values);
}

void PkTransactionBridge::getDetails(const std::vector<std::string>& package_ids) {
    proxy_->callMethod("GetDetails").onInterface(PK_TX_IFACE).withArguments(package_ids);
}

void PkTransactionBridge::getUpdateDetail(const std::vector<std::string>& package_ids) {
    proxy_->callMethod("GetUpdateDetail").onInterface(PK_TX_IFACE).withArguments(package_ids);
}

void PkTransactionBridge::getFiles(const std::vector<std::string>& package_ids) {
    proxy_->callMethod("GetFiles").onInterface(PK_TX_IFACE).withArguments(package_ids);
}

void PkTransactionBridge::getRepoList(uint64_t filter) {
    proxy_->callMethod("GetRepoList").onInterface(PK_TX_IFACE).withArguments(filter);
}

void PkTransactionBridge::dependsOn(uint64_t filter, const std::vector<std::string>& ids,
                                    bool recursive) {
    proxy_->callMethod("DependsOn").onInterface(PK_TX_IFACE).withArguments(filter, ids, recursive);
}

void PkTransactionBridge::requiredBy(uint64_t filter, const std::vector<std::string>& ids,
                                     bool recursive) {
    proxy_->callMethod("RequiredBy").onInterface(PK_TX_IFACE).withArguments(filter, ids, recursive);
}

void PkTransactionBridge::getDistroUpgrades() {
    proxy_->callMethod("GetDistroUpgrades").onInterface(PK_TX_IFACE);
}

void PkTransactionBridge::getOldTransactions(uint32_t number) {
    proxy_->callMethod("GetOldTransactions").onInterface(PK_TX_IFACE).withArguments(number);
}

// ── Write methods ────────────────────────────────────────────────────────────

void PkTransactionBridge::installPackages(uint64_t flags, const std::vector<std::string>& ids) {
    proxy_->callMethod("InstallPackages").onInterface(PK_TX_IFACE).withArguments(flags, ids);
}

void PkTransactionBridge::removePackages(uint64_t flags, const std::vector<std::string>& ids,
                                         bool allow_deps, bool autoremove) {
    proxy_->callMethod("RemovePackages")
        .onInterface(PK_TX_IFACE)
        .withArguments(flags, ids, allow_deps, autoremove);
}

void PkTransactionBridge::updatePackages(uint64_t flags, const std::vector<std::string>& ids) {
    proxy_->callMethod("UpdatePackages").onInterface(PK_TX_IFACE).withArguments(flags, ids);
}

void PkTransactionBridge::refreshCache(bool force) {
    proxy_->callMethod("RefreshCache").onInterface(PK_TX_IFACE).withArguments(force);
}

void PkTransactionBridge::downloadPackages(bool store_in_cache,
                                           const std::vector<std::string>& ids) {
    proxy_->callMethod("DownloadPackages")
        .onInterface(PK_TX_IFACE)
        .withArguments(store_in_cache, ids);
}

void PkTransactionBridge::installFiles(uint64_t flags, const std::vector<std::string>& paths) {
    proxy_->callMethod("InstallFiles").onInterface(PK_TX_IFACE).withArguments(flags, paths);
}

void PkTransactionBridge::repoEnable(const std::string& repo_id, bool enabled) {
    proxy_->callMethod("RepoEnable").onInterface(PK_TX_IFACE).withArguments(repo_id, enabled);
}

void PkTransactionBridge::acceptEula(const std::string& eula_id) {
    proxy_->callMethod("AcceptEula").onInterface(PK_TX_IFACE).withArguments(eula_id);
}

void PkTransactionBridge::cancel() {
    proxy_->callMethod("Cancel").onInterface(PK_TX_IFACE);
}

void PkTransactionBridge::postError(const std::string& message) {
    PkErrorCode ec{.code = 4, .details = message};  // 4 = internal-error
    post(kErrorCode, ec);
    postFinished(2, 0);  // 2 = PK_EXIT_ENUM_FAILED
}

// ── Signal handlers ──────────────────────────────────────────────────────────

void PkTransactionBridge::onPackage(uint32_t info, const std::string& pkg_id,
                                    const std::string& summary) {
    PkPackage p{.info = info, .packageId = pkg_id, .summary = summary};
    post(kPackage, p);
}

void PkTransactionBridge::onProgress(const std::string& pkg_id, uint32_t status, uint32_t pct) {
    PkProgress p{
        .packageId = pkg_id,
        .status = status,
        .percentage = pct,
        .isItem = false,
    };
    post(kProgress, p);
}

void PkTransactionBridge::onItemProgress(const std::string& id, uint32_t status, uint32_t pct) {
    PkProgress p{
        .packageId = id,
        .status = status,
        .percentage = pct,
        .isItem = true,
    };
    post(kProgress, p);
}

void PkTransactionBridge::onStatusChanged(uint32_t status) {
    PkProgress p{
        .packageId = "",
        .status = status,
        .percentage = 101,
        .isItem = false,
    };
    post(kProgress, p);
}

void PkTransactionBridge::onDetails(const std::map<std::string, sdbus::Variant>& data) {
    // Details signal uses a{sv} — extract known keys into PkDetails.
    PkDetails d{};
    auto get_str = [&](const char* key) -> std::string {
        auto it = data.find(key);
        if (it != data.end()) {
            return it->second.get<std::string>();
        }
        return {};
    };
    auto get_u64 = [&](const char* key) -> uint64_t {
        auto it = data.find(key);
        if (it != data.end()) {
            return it->second.get<uint64_t>();
        }
        return 0;
    };

    d.packageId = get_str("package-id");
    d.summary = get_str("summary");
    d.description = get_str("description");
    d.url = get_str("url");
    d.license = get_str("license");
    d.group = get_str("group");
    d.size = get_u64("size");

    post(kDetails, d);
}

void PkTransactionBridge::onUpdateDetail(
    const std::string& pkg_id, const std::vector<std::string>& updates,
    const std::vector<std::string>& obsoletes, const std::vector<std::string>& vendor_urls,
    const std::vector<std::string>& bugzilla_urls, const std::vector<std::string>& cve_urls,
    uint32_t restart, const std::string& update_text, const std::string& changelog, uint32_t state,
    const std::string& issued, const std::string& updated) {
    PkUpdateDetail ud{
        .packageId = pkg_id,
        .updates = updates,
        .obsoletes = obsoletes,
        .vendorUrls = vendor_urls,
        .bugzillaUrls = bugzilla_urls,
        .cveUrls = cve_urls,
        .restart = restart,
        .updateText = update_text,
        .changelog = changelog,
        .state = state,
        .issued = issued,
        .updated = updated,
    };
    post(kUpdateDetail, ud);
}

void PkTransactionBridge::onRepoDetail(const std::string& repo_id, const std::string& desc,
                                       bool enabled) {
    PkRepoDetail rd{.repoId = repo_id, .description = desc, .enabled = enabled};
    post(kRepoDetail, rd);
}

void PkTransactionBridge::onRepoSignatureRequired(
    const std::string& pkg_id, const std::string& repo_name, const std::string& key_url,
    const std::string& key_userid, const std::string& key_id, const std::string& fingerprint,
    const std::string& timestamp, uint32_t type) {
    PkRepoSigRequired rs{
        .packageId = pkg_id,
        .repositoryName = repo_name,
        .keyUrl = key_url,
        .keyUserId = key_userid,
        .keyId = key_id,
        .keyFingerprint = fingerprint,
        .keyTimestamp = timestamp,
        .type = type,
    };
    post(kRepoSigReq, rs);
}

void PkTransactionBridge::onEulaRequired(const std::string& eula_id, const std::string& pkg_id,
                                         const std::string& vendor, const std::string& license) {
    PkEulaRequired e{
        .eulaId = eula_id,
        .packageId = pkg_id,
        .vendorName = vendor,
        .licenseAgreement = license,
    };
    post(kEulaRequired, e);
}

void PkTransactionBridge::onFiles(const std::string& pkg_id,
                                  const std::vector<std::string>& files) {
    PkFiles f{.packageId = pkg_id, .files = files};
    post(kFiles, f);
}

void PkTransactionBridge::onErrorCode(uint32_t code, const std::string& details) {
    PkErrorCode ec{.code = code, .details = details};
    post(kErrorCode, ec);
}

void PkTransactionBridge::onRequireRestart(uint32_t type, const std::string& pkg_id) {
    PkRequireRestart rr{.type = type, .packageId = pkg_id};
    post(kRequireRestart, rr);
}

void PkTransactionBridge::onMessage(uint32_t type, const std::string& details) {
    PkMessage m{.type = type, .details = details};
    post(kMessage, m);
}

void PkTransactionBridge::onFinished(uint32_t exit_code, uint32_t runtime_ms) {
    postFinished(exit_code, runtime_ms);
}

void PkTransactionBridge::onDestroy() {
    // Transaction object self-destructs on the daemon side.
    // The Dart layer will drop the bridge after receiving the sentinel.
}

// ── Post helpers ─────────────────────────────────────────────────────────────

template <typename T>
void PkTransactionBridge::post(uint8_t discriminator, const T& value) {
    auto payload = glz::encode(value);

    std::vector<uint8_t> buf;
    buf.reserve(1 + payload.size());
    buf.push_back(discriminator);
    buf.insert(buf.end(), payload.begin(), payload.end());

    Dart_CObject obj;
    obj.type = Dart_CObject_kTypedData;
    obj.value.as_typed_data.type = Dart_TypedData_kUint8;
    obj.value.as_typed_data.length = static_cast<intptr_t>(buf.size());
    obj.value.as_typed_data.values = buf.data();
    Dart_PostCObject_DL(port_, &obj);
}

void PkTransactionBridge::postFinished(uint32_t exit_code, uint32_t runtime_ms) {
    // Post 0x20 Finished marker with exit code and runtime.
    std::vector<uint8_t> buf;
    buf.push_back(kFinished);
    glz::detail::encode_field(buf, exit_code);
    glz::detail::encode_field(buf, runtime_ms);

    Dart_CObject obj;
    obj.type = Dart_CObject_kTypedData;
    obj.value.as_typed_data.type = Dart_TypedData_kUint8;
    obj.value.as_typed_data.length = static_cast<intptr_t>(buf.size());
    obj.value.as_typed_data.values = buf.data();
    Dart_PostCObject_DL(port_, &obj);

    // Post 0xFF sentinel.
    uint8_t sentinel = kSentinel;
    Dart_CObject sentinel_obj;
    sentinel_obj.type = Dart_CObject_kTypedData;
    sentinel_obj.value.as_typed_data.type = Dart_TypedData_kUint8;
    sentinel_obj.value.as_typed_data.length = 1;
    sentinel_obj.value.as_typed_data.values = &sentinel;
    Dart_PostCObject_DL(port_, &sentinel_obj);
}

// Explicit template instantiations for all posted types.
template void PkTransactionBridge::post<PkPackage>(uint8_t, const PkPackage&);
template void PkTransactionBridge::post<PkProgress>(uint8_t, const PkProgress&);
template void PkTransactionBridge::post<PkDetails>(uint8_t, const PkDetails&);
template void PkTransactionBridge::post<PkUpdateDetail>(uint8_t, const PkUpdateDetail&);
template void PkTransactionBridge::post<PkRepoDetail>(uint8_t, const PkRepoDetail&);
template void PkTransactionBridge::post<PkFiles>(uint8_t, const PkFiles&);
template void PkTransactionBridge::post<PkErrorCode>(uint8_t, const PkErrorCode&);
template void PkTransactionBridge::post<PkMessage>(uint8_t, const PkMessage&);
template void PkTransactionBridge::post<PkEulaRequired>(uint8_t, const PkEulaRequired&);
template void PkTransactionBridge::post<PkRepoSigRequired>(uint8_t, const PkRepoSigRequired&);
template void PkTransactionBridge::post<PkRequireRestart>(uint8_t, const PkRequireRestart&);
