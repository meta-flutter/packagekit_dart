// codec.dart — GlazeCodec for decoding native_comms Channel B payloads.

import 'dart:convert';
import 'dart:typed_data';

import '../details.dart';
import '../enums.dart';
import '../package.dart';
import '../repo.dart';
import '../transaction.dart' show PkProgress;
import 'types.dart';

/// Decodes glaze binary payloads from the native bridge.
/// Matches the encoding in glaze_meta.h (little-endian, length-prefixed strings).
class GlazeCodec {
  GlazeCodec._();

  static T decode<T>(Uint8List data, int offset) {
    final r = _Reader(data, offset);

    if (T == PkPackage) {
      return _decodePackage(r) as T;
    } else if (T == PkProgress) {
      return _decodeProgress(r) as T;
    } else if (T == PkPackageDetail) {
      return _decodeDetails(r) as T;
    } else if (T == PkUpdateDetail) {
      return _decodeUpdateDetail(r) as T;
    } else if (T == PkRepoDetail) {
      return _decodeRepoDetail(r) as T;
    } else if (T == PkFiles) {
      return _decodeFiles(r) as T;
    } else if (T == PkErrorCode) {
      return _decodeErrorCode(r) as T;
    } else if (T == PkMessage) {
      return _decodeMessage(r) as T;
    } else if (T == PkEulaRequired) {
      return _decodeEulaRequired(r) as T;
    } else if (T == PkRepoSigRequired) {
      return _decodeRepoSigRequired(r) as T;
    } else if (T == PkRequireRestart) {
      return _decodeRequireRestart(r) as T;
    } else if (T == PkManagerProps) {
      return _decodeManagerProps(r) as T;
    } else if (T == PkFinished) {
      return _decodeFinished(r) as T;
    }
    throw ArgumentError('Unknown type: $T');
  }

  static PkPackage _decodePackage(_Reader r) {
    final info = r.readUint32();
    final packageId = r.readString();
    final summary = r.readString();
    return PkPackage(
      info: PkInfo.fromInt(info),
      id: PkPackageId.parse(packageId),
      summary: summary,
    );
  }

  static PkProgress _decodeProgress(_Reader r) {
    final packageId = r.readString();
    final status = r.readUint32();
    final percentage = r.readUint32();
    final isItem = r.readBool();
    return PkProgress(
      packageId: packageId,
      status: PkStatus.fromInt(status),
      percentage: percentage,
      isItem: isItem,
    );
  }

  static PkPackageDetail _decodeDetails(_Reader r) {
    final packageId = r.readString();
    final summary = r.readString();
    final description = r.readString();
    final url = r.readString();
    final license = r.readString();
    final group = r.readString();
    final size = r.readUint64();
    return PkPackageDetail(
      id: PkPackageId.parse(packageId),
      summary: summary,
      description: description,
      url: url,
      license: license,
      group: group,
      size: size,
    );
  }

  static PkUpdateDetail _decodeUpdateDetail(_Reader r) {
    final packageId = r.readString();
    final updates = r.readStringList();
    final obsoletes = r.readStringList();
    final vendorUrls = r.readStringList();
    final bugzillaUrls = r.readStringList();
    final cveUrls = r.readStringList();
    final restart = r.readUint32();
    final updateText = r.readString();
    final changelog = r.readString();
    final state = r.readUint32();
    final issued = r.readString();
    final updated = r.readString();
    return PkUpdateDetail(
      packageId: packageId,
      updates: updates,
      obsoletes: obsoletes,
      vendorUrls: vendorUrls,
      bugzillaUrls: bugzillaUrls,
      cveUrls: cveUrls,
      restart: restart,
      updateText: updateText,
      changelog: changelog,
      state: state,
      issued: issued,
      updated: updated,
    );
  }

  static PkRepoDetail _decodeRepoDetail(_Reader r) {
    final repoId = r.readString();
    final description = r.readString();
    final enabled = r.readBool();
    return PkRepoDetail(
      repoId: repoId,
      description: description,
      enabled: enabled,
    );
  }

  static PkFiles _decodeFiles(_Reader r) {
    final packageId = r.readString();
    final files = r.readStringList();
    return PkFiles(packageId: packageId, files: files);
  }

  static PkErrorCode _decodeErrorCode(_Reader r) {
    final code = r.readUint32();
    final details = r.readString();
    return PkErrorCode(code: code, details: details);
  }

  static PkMessage _decodeMessage(_Reader r) {
    final type = r.readUint32();
    final details = r.readString();
    return PkMessage(type: type, details: details);
  }

  static PkEulaRequired _decodeEulaRequired(_Reader r) {
    final eulaId = r.readString();
    final packageId = r.readString();
    final vendorName = r.readString();
    final licenseAgreement = r.readString();
    return PkEulaRequired(
      eulaId: eulaId,
      packageId: packageId,
      vendorName: vendorName,
      licenseAgreement: licenseAgreement,
    );
  }

  static PkRepoSigRequired _decodeRepoSigRequired(_Reader r) {
    final packageId = r.readString();
    final repositoryName = r.readString();
    final keyUrl = r.readString();
    final keyUserId = r.readString();
    final keyId = r.readString();
    final keyFingerprint = r.readString();
    final keyTimestamp = r.readString();
    final type = r.readUint32();
    return PkRepoSigRequired(
      packageId: packageId,
      repositoryName: repositoryName,
      keyUrl: keyUrl,
      keyUserId: keyUserId,
      keyId: keyId,
      keyFingerprint: keyFingerprint,
      keyTimestamp: keyTimestamp,
      type: type,
    );
  }

  static PkRequireRestart _decodeRequireRestart(_Reader r) {
    final type = r.readUint32();
    final packageId = r.readString();
    return PkRequireRestart(type: type, packageId: packageId);
  }

  static PkManagerProps _decodeManagerProps(_Reader r) {
    final backendName = r.readString();
    final backendDescription = r.readString();
    final backendAuthor = r.readString();
    final roles = r.readUint64();
    final filters = r.readUint64();
    final groups = r.readUint64();
    final mimeTypes = r.readStringList();
    final distroId = r.readString();
    final networkState = r.readUint32();
    final locked = r.readBool();
    final versionMajor = r.readUint32();
    final versionMinor = r.readUint32();
    final versionMicro = r.readUint32();
    return PkManagerProps(
      backendName: backendName,
      backendDescription: backendDescription,
      backendAuthor: backendAuthor,
      roles: roles,
      filters: filters,
      groups: groups,
      mimeTypes: mimeTypes,
      distroId: distroId,
      networkState: networkState,
      locked: locked,
      versionMajor: versionMajor,
      versionMinor: versionMinor,
      versionMicro: versionMicro,
    );
  }

  static PkFinished _decodeFinished(_Reader r) {
    final exitCode = r.readUint32();
    final runtimeMs = r.readUint32();
    return PkFinished(exitCode: exitCode, runtimeMs: runtimeMs);
  }
}

/// Little-endian binary reader matching glaze_meta.h encoding.
class _Reader {
  final ByteData _data;
  final int _length;
  int _offset;

  _Reader(Uint8List bytes, int offset)
    : _data = bytes.buffer.asByteData(bytes.offsetInBytes),
      _length = bytes.length,
      _offset = offset;

  void _checkBounds(int needed) {
    if (_offset + needed > _length) {
      throw RangeError(
        'Codec read overrun: need $needed bytes at '
        'offset $_offset, but buffer is $_length bytes',
      );
    }
  }

  int readUint32() {
    _checkBounds(4);
    final v = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  int readUint64() {
    _checkBounds(8);
    final v = _data.getUint64(_offset, Endian.little);
    _offset += 8;
    return v;
  }

  bool readBool() {
    _checkBounds(1);
    final v = _data.getUint8(_offset) != 0;
    _offset += 1;
    return v;
  }

  String readString() {
    final len = readUint32();
    _checkBounds(len);
    final bytes = Uint8List.view(
      _data.buffer,
      _data.offsetInBytes + _offset,
      len,
    );
    _offset += len;
    return utf8.decode(bytes);
  }

  List<String> readStringList() {
    final count = readUint32();
    return List.generate(count, (_) => readString());
  }
}
