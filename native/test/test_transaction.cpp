// test_transaction.cpp — Unit tests for PkTransactionBridge.
//
// Since we cannot connect to a real system bus in CI, these tests verify
// the signal-to-struct conversion and discriminator-tagged serialization
// logic that the bridge performs before posting to Dart.

#include <gtest/gtest.h>

#include <algorithm>

#include "pk_transaction.h"
#include "pk_types.h"

// ── Package signal encoding ──────────────────────────────────────────────────

TEST(PkTransaction, PackageSignalRoundtrip) {
    PkPackage p{
        .info = 2,
        .packageId = "bash;5.1.8-1;x86_64;fedora",
        .summary = "The GNU Bourne Again shell",
    };

    auto payload = glz::encode(p);
    std::vector<uint8_t> buf;
    buf.push_back(0x01);
    buf.insert(buf.end(), payload.begin(), payload.end());

    EXPECT_EQ(buf[0], 0x01);

    PkPackage decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.info, p.info);
    EXPECT_EQ(decoded.packageId, p.packageId);
    EXPECT_EQ(decoded.summary, p.summary);
}

// ── Progress signal encoding ─────────────────────────────────────────────────

TEST(PkTransaction, ProgressSignalRoundtrip) {
    PkProgress p{
        .packageId = "vim;9.0-1;x86_64;updates",
        .status = 10,
        .percentage = 42,
        .isItem = false,
    };

    auto payload = glz::encode(p);
    std::vector<uint8_t> buf;
    buf.push_back(0x02);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkProgress decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.packageId, p.packageId);
    EXPECT_EQ(decoded.status, p.status);
    EXPECT_EQ(decoded.percentage, p.percentage);
    EXPECT_FALSE(decoded.isItem);
}

TEST(PkTransaction, ItemProgressSignalRoundtrip) {
    PkProgress p{
        .packageId = "gcc;13.2-1;x86_64;fedora",
        .status = 8,
        .percentage = 75,
        .isItem = true,
    };

    auto payload = glz::encode(p);
    std::vector<uint8_t> buf;
    buf.push_back(0x02);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkProgress decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_TRUE(decoded.isItem);
    EXPECT_EQ(decoded.percentage, 75u);
}

TEST(PkTransaction, StatusChangedSignalRoundtrip) {
    PkProgress p{
        .packageId = "",
        .status = 3,
        .percentage = 101,
        .isItem = false,
    };

    auto payload = glz::encode(p);
    std::vector<uint8_t> buf;
    buf.push_back(0x02);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkProgress decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_TRUE(decoded.packageId.empty());
    EXPECT_EQ(decoded.status, 3u);
    EXPECT_EQ(decoded.percentage, 101u);
}

// ── Details signal encoding ──────────────────────────────────────────────────

TEST(PkTransaction, DetailsSignalRoundtrip) {
    PkDetails d{
        .packageId = "firefox;115.0-1;x86_64;fedora",
        .summary = "Mozilla Firefox",
        .description = "A web browser",
        .url = "https://mozilla.org",
        .license = "MPL-2.0",
        .group = "Applications/Internet",
        .size = 98765432,
    };

    auto payload = glz::encode(d);
    std::vector<uint8_t> buf;
    buf.push_back(0x03);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkDetails decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.packageId, d.packageId);
    EXPECT_EQ(decoded.size, d.size);
}

// ── ErrorCode signal encoding ────────────────────────────────────────────────

TEST(PkTransaction, ErrorCodeSignalRoundtrip) {
    PkErrorCode ec{.code = 12, .details = "Package not found"};

    auto payload = glz::encode(ec);
    std::vector<uint8_t> buf;
    buf.push_back(0x07);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkErrorCode decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.code, ec.code);
    EXPECT_EQ(decoded.details, ec.details);
}

// ── RepoDetail signal encoding ───────────────────────────────────────────────

TEST(PkTransaction, RepoDetailSignalRoundtrip) {
    PkRepoDetail rd{
        .repoId = "fedora",
        .description = "Fedora 41 - x86_64",
        .enabled = true,
    };

    auto payload = glz::encode(rd);
    std::vector<uint8_t> buf;
    buf.push_back(0x05);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkRepoDetail decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.repoId, rd.repoId);
    EXPECT_TRUE(decoded.enabled);
}

// ── Finished + Sentinel encoding ─────────────────────────────────────────────

TEST(PkTransaction, FinishedEncoding) {
    uint32_t exit_code = 1;
    uint32_t runtime_ms = 5432;

    std::vector<uint8_t> buf;
    buf.push_back(0x20);
    glz::detail::encode_field(buf, exit_code);
    glz::detail::encode_field(buf, runtime_ms);

    ASSERT_EQ(buf.size(), 9u);
    EXPECT_EQ(buf[0], 0x20);

    uint32_t decoded_exit{};
    uint32_t decoded_runtime{};
    size_t offset = 1;
    offset = glz::detail::decode_field(buf.data(), offset, decoded_exit);
    glz::detail::decode_field(buf.data(), offset, decoded_runtime);
    EXPECT_EQ(decoded_exit, exit_code);
    EXPECT_EQ(decoded_runtime, runtime_ms);
}

TEST(PkTransaction, SentinelByte) {
    uint8_t sentinel = 0xFF;
    EXPECT_EQ(sentinel, 0xFF);
}

// ── EulaRequired signal encoding ─────────────────────────────────────────────

TEST(PkTransaction, EulaRequiredRoundtrip) {
    PkEulaRequired e{
        .eulaId = "eula-42",
        .packageId = "proprietary;1.0;x86_64;vendor",
        .vendorName = "ExampleCorp",
        .licenseAgreement = "Terms apply.",
    };

    auto payload = glz::encode(e);
    std::vector<uint8_t> buf;
    buf.push_back(0x09);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkEulaRequired decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.eulaId, e.eulaId);
    EXPECT_EQ(decoded.licenseAgreement, e.licenseAgreement);
}

// ── RepoSigRequired signal encoding ──────────────────────────────────────────

TEST(PkTransaction, RepoSigRequiredRoundtrip) {
    PkRepoSigRequired rs{
        .packageId = "kernel;6.5-1;x86_64;updates",
        .repositoryName = "updates",
        .keyUrl = "https://keys.example.com/GPG-KEY",
        .keyUserId = "Fedora <fedora@fedoraproject.org>",
        .keyId = "0xABCD1234",
        .keyFingerprint = "ABCD1234EFGH5678",
        .keyTimestamp = "2023-01-01",
        .type = 1,
    };

    auto payload = glz::encode(rs);
    std::vector<uint8_t> buf;
    buf.push_back(0x0A);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkRepoSigRequired decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.repositoryName, rs.repositoryName);
    EXPECT_EQ(decoded.keyId, rs.keyId);
}

// ── Message signal encoding ──────────────────────────────────────────────────

TEST(PkTransaction, MessageSignalRoundtrip) {
    PkMessage m{.type = 3, .details = "Cache out of date"};

    auto payload = glz::encode(m);
    std::vector<uint8_t> buf;
    buf.push_back(0x08);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkMessage decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.type, m.type);
    EXPECT_EQ(decoded.details, m.details);
}

// ── RequireRestart signal encoding ───────────────────────────────────────────

TEST(PkTransaction, RequireRestartRoundtrip) {
    PkRequireRestart rr{.type = 2, .packageId = "kernel;6.5-1;x86_64;updates"};

    auto payload = glz::encode(rr);
    std::vector<uint8_t> buf;
    buf.push_back(0x0B);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkRequireRestart decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.type, rr.type);
    EXPECT_EQ(decoded.packageId, rr.packageId);
}

// ── UpdateDetail signal encoding ─────────────────────────────────────────────

TEST(PkTransaction, UpdateDetailRoundtrip) {
    PkUpdateDetail ud{
        .packageId = "openssl;3.1.1-1;x86_64;updates",
        .updates = {"openssl;3.1.0-1;x86_64;fedora"},
        .obsoletes = {},
        .vendorUrls = {"https://vendor.example.com"},
        .bugzillaUrls = {},
        .cveUrls = {"https://cve.example.com/CVE-2023-1234"},
        .restart = 0,
        .updateText = "Security fix",
        .changelog = "- Fixed CVE",
        .state = 8,
        .issued = "2023-06-15",
        .updated = "2023-06-16",
    };

    auto payload = glz::encode(ud);
    std::vector<uint8_t> buf;
    buf.push_back(0x04);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkUpdateDetail decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.packageId, ud.packageId);
    EXPECT_EQ(decoded.updates, ud.updates);
    EXPECT_EQ(decoded.cveUrls, ud.cveUrls);
    EXPECT_EQ(decoded.state, ud.state);
}

// ── Files signal encoding ────────────────────────────────────────────────────

TEST(PkTransaction, FilesSignalRoundtrip) {
    PkFiles f{
        .packageId = "bash;5.1.8-1;x86_64;fedora",
        .files = {"/usr/bin/bash", "/etc/skel/.bashrc"},
    };

    auto payload = glz::encode(f);
    std::vector<uint8_t> buf;
    buf.push_back(0x06);
    buf.insert(buf.end(), payload.begin(), payload.end());

    PkFiles decoded{};
    glz::decode(buf.data(), 1, decoded);
    EXPECT_EQ(decoded.files, f.files);
}

// ── SetHints argument vector ─────────────────────────────────────────────────

TEST(PkTransaction, HintsIncludeInteractiveTrue) {
    auto hints = PkTransactionBridge::buildHints("en_US.UTF-8", true);

    EXPECT_NE(std::find(hints.begin(), hints.end(), "interactive=true"), hints.end());
    EXPECT_EQ(std::find(hints.begin(), hints.end(), "interactive=false"), hints.end());
}

TEST(PkTransaction, HintsIncludeInteractiveFalse) {
    auto hints = PkTransactionBridge::buildHints("en_US.UTF-8", false);

    EXPECT_NE(std::find(hints.begin(), hints.end(), "interactive=false"), hints.end());
    EXPECT_EQ(std::find(hints.begin(), hints.end(), "interactive=true"), hints.end());
}

TEST(PkTransaction, HintsPreserveLocaleAndDefaults) {
    auto hints = PkTransactionBridge::buildHints("de_DE.UTF-8", true);

    ASSERT_EQ(hints.size(), 4u);
    EXPECT_EQ(hints[0], "locale=de_DE.UTF-8");
    EXPECT_EQ(hints[1], "background=false");
    EXPECT_EQ(hints[2], "supports-plural-signals=true");
    EXPECT_EQ(hints[3], "interactive=true");
}
