// pk_transaction.h
//
// PkTransactionBridge wraps one PackageKit transaction object path.
//
// Lifecycle (matches PackageKit protocol):
//   1. PkManager::createTransaction()  -> transaction object path
//   2. PkTransactionBridge::create()   -> proxy on that path
//   3. setHints()                      -> mandatory first call
//   4. invoke method (searchName, etc.)
//   5. signals stream -> Dart_PostCObject_DL
//   6. Finished signal -> 0x20 posted, then 0xFF sentinel
//   7. Destroy signal  -> bridge self-destructs, proxy dropped
//
// The sdbus event loop thread delivers all signals. Handlers are
// registered before invoking the method to guarantee no signal is missed.

#pragma once
#include <sdbus-c++/sdbus-c++.h>

#include <memory>
#include <string>
#include <vector>

#include "dart_api_dl.h"
#include "pk_types.h"

class PkTransactionBridge {
   public:
    // Takes ownership of connection reference.
    // object_path: returned by CreateTransaction on the manager.
    PkTransactionBridge(sdbus::IConnection& conn, sdbus::ObjectPath object_path,
                        Dart_Port dart_port);

    ~PkTransactionBridge();

    PkTransactionBridge(const PkTransactionBridge&) = delete;
    PkTransactionBridge& operator=(const PkTransactionBridge&) = delete;

    // Builds the SetHints argument vector. Separated from setHints so it can
    // be tested without a bus connection.
    static std::vector<std::string> buildHints(const std::string& locale, bool interactive);

    // Must be called before any method invocation.
    // Sends locale, background flag, supports-plural-signals, interactive.
    //
    // interactive gates whether polkit may prompt the user for authorization.
    // It must be sent explicitly: the daemon treats an absent hint as false.
    void setHints(const std::string& locale = "en_US.UTF-8", bool interactive = true);

    // ── Query methods ────────────────────────────────────────────────
    void searchName(uint64_t filter, const std::vector<std::string>& values);
    void searchDetails(uint64_t filter, const std::vector<std::string>& values);
    void searchFiles(uint64_t filter, const std::vector<std::string>& values);
    void searchGroups(uint64_t filter, const std::vector<std::string>& values);
    void getPackages(uint64_t filter);
    void getUpdates(uint64_t filter);
    void resolve(uint64_t filter, const std::vector<std::string>& package_ids);
    void whatProvides(uint64_t filter, const std::vector<std::string>& values);
    void getDetails(const std::vector<std::string>& package_ids);
    void getUpdateDetail(const std::vector<std::string>& package_ids);
    void getFiles(const std::vector<std::string>& package_ids);
    void getRepoList(uint64_t filter);
    void dependsOn(uint64_t filter, const std::vector<std::string>& ids, bool recursive);
    void requiredBy(uint64_t filter, const std::vector<std::string>& ids, bool recursive);
    void getDistroUpgrades();
    void getOldTransactions(uint32_t number);

    // ── Write methods ────────────────────────────────────────────────
    void installPackages(uint64_t flags, const std::vector<std::string>& ids);
    void removePackages(uint64_t flags, const std::vector<std::string>& ids, bool allow_deps,
                        bool autoremove);
    void updatePackages(uint64_t flags, const std::vector<std::string>& ids);
    void refreshCache(bool force);
    void downloadPackages(bool store_in_cache, const std::vector<std::string>& ids);
    void installFiles(uint64_t flags, const std::vector<std::string>& paths);
    void repoEnable(const std::string& repo_id, bool enabled);
    void acceptEula(const std::string& eula_id);
    void cancel();

    // Post a synthetic error + finished(failed) to the Dart port.
    // Called by the C ABI bridge when a D-Bus method call throws.
    void postError(const std::string& message);

   private:
    // Signal handlers — all called on the sdbus event loop thread.
    void onPackage(uint32_t info, const std::string& pkg_id, const std::string& summary);
    void onProgress(const std::string& pkg_id, uint32_t status, uint32_t pct);
    void onItemProgress(const std::string& id, uint32_t status, uint32_t pct);
    void onStatusChanged(uint32_t status);
    void onDetails(const std::map<std::string, sdbus::Variant>& data);
    void onUpdateDetail(const std::string& pkg_id, const std::vector<std::string>& updates,
                        const std::vector<std::string>& obsoletes,
                        const std::vector<std::string>& vendor_urls,
                        const std::vector<std::string>& bugzilla_urls,
                        const std::vector<std::string>& cve_urls, uint32_t restart,
                        const std::string& update_text, const std::string& changelog,
                        uint32_t state, const std::string& issued, const std::string& updated);
    void onRepoDetail(const std::string& repo_id, const std::string& desc, bool enabled);
    void onRepoSignatureRequired(const std::string& pkg_id, const std::string& repo_name,
                                 const std::string& key_url, const std::string& key_userid,
                                 const std::string& key_id, const std::string& fingerprint,
                                 const std::string& timestamp, uint32_t type);
    void onEulaRequired(const std::string& eula_id, const std::string& pkg_id,
                        const std::string& vendor, const std::string& license);
    void onFiles(const std::string& pkg_id, const std::vector<std::string>& files);
    void onErrorCode(uint32_t code, const std::string& details);
    void onRequireRestart(uint32_t type, const std::string& pkg_id);
    void onMessage(uint32_t type, const std::string& details);
    void onFinished(uint32_t exit_code, uint32_t runtime_ms);
    void onDestroy();

    // Post a glaze-encoded payload to Dart with the given discriminator.
    template <typename T>
    void post(uint8_t discriminator, const T& value);

    // Post the 0x20 Finished marker, then 0xFF sentinel.
    void postFinished(uint32_t exit_code, uint32_t runtime_ms);

    sdbus::ObjectPath path_;
    Dart_Port port_;
    std::unique_ptr<sdbus::IProxy> proxy_;
};
