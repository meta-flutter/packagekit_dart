// pk_bridge.h — C ABI exported to Dart FFI.
//
// All handles are opaque void*.
// All results delivered via Dart_PostCObject_DL (kExternalTypedData).
//
// Message discriminator byte at offset 0 (see pk_types.h):
//   0x01 = PkPackage         0x02 = PkProgress    0x03 = PkDetails
//   0x04 = PkUpdateDetail    0x05 = PkRepoDetail  0x06 = PkFiles
//   0x07 = PkErrorCode       0x08 = PkMessage     0x09 = PkEulaRequired
//   0x0A = PkRepoSigRequired 0x0B = PkRequireRestart
//   0x0C = PkManagerProps    0x20 = Finished
//   0xFF = stream sentinel
//
// PackageKit handles polkit internally via packagekitd. No special
// privilege escalation is needed in the bridge code.

#pragma once
#include <stdbool.h>
#include <stdint.h>

#include "dart_api_dl.h"

#define PK_EXPORT __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif

// Initialize Dart API dynamic linking. Call once at startup.
PK_EXPORT void pk_bridge_init(void* dart_api_dl_data);

// ── Manager ──────────────────────────────────────────────────────────────────
// events_port receives: 0x0C PkManagerProps on connect, then
//   UpdatesChanged / RepoListChanged / NetworkStateChanged daemon signals.
PK_EXPORT void* pk_manager_create(Dart_Port events_port);
PK_EXPORT void pk_manager_destroy(void* handle);
PK_EXPORT void pk_manager_read_properties(void* handle);

// ── Transaction ───────────────────────────────────────────────────────────────
PK_EXPORT void* pk_transaction_create(void* manager, Dart_Port tx_port);
PK_EXPORT void pk_transaction_destroy(void* handle);
// interactive: when true, the daemon may ask polkit to prompt the user for
// authorization. When false, an unauthorized transaction fails immediately.
PK_EXPORT void pk_transaction_set_hints(void* handle, const char* locale, bool interactive);

// ── Query methods ─────────────────────────────────────────────────────────────
PK_EXPORT void pk_search_name(void* handle, uint64_t filter, const char* const* values,
                              int n_values);
PK_EXPORT void pk_search_details(void* handle, uint64_t filter, const char* const* values,
                                 int n_values);
PK_EXPORT void pk_search_files(void* handle, uint64_t filter, const char* const* values,
                               int n_values);
PK_EXPORT void pk_search_groups(void* handle, uint64_t filter, const char* const* values,
                                int n_values);
PK_EXPORT void pk_get_packages(void* handle, uint64_t filter);
PK_EXPORT void pk_get_updates(void* handle, uint64_t filter);
PK_EXPORT void pk_resolve(void* handle, uint64_t filter, const char* const* ids, int n_ids);
PK_EXPORT void pk_what_provides(void* handle, uint64_t filter, const char* const* values,
                                int n_values);
PK_EXPORT void pk_get_details(void* handle, const char* const* ids, int n_ids);
PK_EXPORT void pk_get_update_detail(void* handle, const char* const* ids, int n_ids);
PK_EXPORT void pk_get_files(void* handle, const char* const* ids, int n_ids);
PK_EXPORT void pk_get_repo_list(void* handle, uint64_t filter);
PK_EXPORT void pk_depends_on(void* handle, uint64_t filter, const char* const* ids, int n_ids,
                             bool recursive);
PK_EXPORT void pk_required_by(void* handle, uint64_t filter, const char* const* ids, int n_ids,
                              bool recursive);
PK_EXPORT void pk_get_distro_upgrades(void* handle);
PK_EXPORT void pk_get_old_transactions(void* handle, uint32_t number);

// ── Write methods (polkit handled by packagekitd) ──────────────────────────
PK_EXPORT void pk_install_packages(void* handle, uint64_t flags, const char* const* ids, int n_ids);
PK_EXPORT void pk_remove_packages(void* handle, uint64_t flags, const char* const* ids, int n_ids,
                                  bool allow_deps, bool autoremove);
PK_EXPORT void pk_update_packages(void* handle, uint64_t flags, const char* const* ids, int n_ids);
PK_EXPORT void pk_refresh_cache(void* handle, bool force);
PK_EXPORT void pk_download_packages(void* handle, bool store_in_cache, const char* const* ids,
                                    int n_ids);
PK_EXPORT void pk_install_files(void* handle, uint64_t flags, const char* const* paths,
                                int n_paths);
PK_EXPORT void pk_repo_enable(void* handle, const char* repo_id, bool enabled);
PK_EXPORT void pk_accept_eula(void* handle, const char* eula_id);
PK_EXPORT void pk_cancel(void* handle);

#ifdef __cplusplus
}
#endif
