// dispatcher.dart — testable message dispatch for transaction and manager events.

import 'dart:async';
import 'dart:typed_data';

import '../details.dart';
import '../enums.dart';
import '../exceptions.dart';
import '../ffi/codec.dart';
import '../ffi/types.dart';
import '../package.dart';
import '../repo.dart';
import '../transaction.dart';

/// Dispatches raw binary messages from a transaction port to typed streams.
class TransactionDispatcher {
  final StreamController<PkPackage> packages = StreamController();
  final StreamController<PkPackageDetail> details = StreamController();
  final StreamController<PkUpdateDetail> updateDetails = StreamController();
  final StreamController<PkRepoDetail> repoDetails = StreamController();
  final StreamController<PkFiles> files = StreamController();
  final StreamController<PkProgress> progress = StreamController();
  final StreamController<PkMessage> messages = StreamController();
  final StreamController<PkEulaRequired> eulaRequired = StreamController();
  final StreamController<PkRepoSigRequired> repoSigRequired =
      StreamController();
  final StreamController<PkRequireRestart> requireRestart = StreamController();
  final StreamController<PkErrorCode> errors = StreamController();
  final Completer<PkTransactionResult> done = Completer();

  bool _finished = false;
  bool get finished => _finished;

  /// Process a raw binary message from the native bridge.
  void dispatch(Uint8List msg) {
    try {
      final disc = msg[0];
      switch (disc) {
        case 0x01:
          packages.add(GlazeCodec.decode<PkPackage>(msg, 1));
        case 0x02:
          progress.add(GlazeCodec.decode<PkProgress>(msg, 1));
        case 0x03:
          details.add(GlazeCodec.decode<PkPackageDetail>(msg, 1));
        case 0x04:
          updateDetails.add(GlazeCodec.decode<PkUpdateDetail>(msg, 1));
        case 0x05:
          repoDetails.add(GlazeCodec.decode<PkRepoDetail>(msg, 1));
        case 0x06:
          files.add(GlazeCodec.decode<PkFiles>(msg, 1));
        case 0x07:
          errors.add(GlazeCodec.decode<PkErrorCode>(msg, 1));
        case 0x08:
          messages.add(GlazeCodec.decode<PkMessage>(msg, 1));
        case 0x09:
          eulaRequired.add(GlazeCodec.decode<PkEulaRequired>(msg, 1));
        case 0x0A:
          repoSigRequired.add(GlazeCodec.decode<PkRepoSigRequired>(msg, 1));
        case 0x0B:
          requireRestart.add(GlazeCodec.decode<PkRequireRestart>(msg, 1));
        case 0x20:
          final result = GlazeCodec.decode<PkFinished>(msg, 1);
          final exit = PkExit.fromInt(result.exitCode);
          if (!done.isCompleted) {
            if (exit == PkExit.success) {
              done.complete(
                PkTransactionResult(exit: exit, runtimeMs: result.runtimeMs),
              );
            } else {
              done.completeError(
                PkTransactionException(
                  'Transaction failed: ${exit.name}',
                  exit: exit,
                  runtimeMs: result.runtimeMs,
                ),
              );
            }
          }
        case 0xFF:
          Future.microtask(close);
      }
    } on Object catch (e) {
      if (!done.isCompleted) {
        done.completeError(PkException('Internal decode error: $e'));
      }
      Future.microtask(close);
    }
  }

  /// Close all streams.
  void close() {
    _finished = true;
    for (final c in [
      packages,
      details,
      updateDetails,
      repoDetails,
      files,
      progress,
      messages,
      eulaRequired,
      repoSigRequired,
      requireRestart,
      errors,
    ]) {
      if (!c.isClosed) c.close();
    }
  }
}

/// Result of dispatching a manager event.
sealed class ManagerEvent {}

class ManagerPropsEvent extends ManagerEvent {
  final PkManagerProps props;
  ManagerPropsEvent(this.props);
}

class ManagerUpdatesChangedEvent extends ManagerEvent {}

class ManagerRepoListChangedEvent extends ManagerEvent {}

class ManagerNetworkStateChangedEvent extends ManagerEvent {
  final int state;
  ManagerNetworkStateChangedEvent(this.state);
}

/// Dispatch a raw binary manager event message.
/// Returns null for unrecognized or non-Uint8List messages.
ManagerEvent? dispatchManagerEvent(dynamic msg) {
  if (msg is! Uint8List) return null;
  switch (msg[0]) {
    case 0x0C:
      return ManagerPropsEvent(GlazeCodec.decode<PkManagerProps>(msg, 1));
    case 0xD0:
      return ManagerUpdatesChangedEvent();
    case 0xD1:
      return ManagerRepoListChangedEvent();
    case 0xD2:
      final state = msg.buffer
          .asByteData(msg.offsetInBytes)
          .getUint32(1, Endian.little);
      return ManagerNetworkStateChangedEvent(state);
    default:
      return null;
  }
}
