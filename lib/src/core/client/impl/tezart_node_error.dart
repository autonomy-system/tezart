import 'package:meta/meta.dart';

import 'package:tezart/src/common/exceptions/common_exception.dart';
import 'package:tezart/src/common/utils/enum_util.dart';
import 'package:tezart/src/common/utils/map_extension.dart';
import 'package:tezart/src/core/rpc/rpc_interface.dart';

/// Exhaustive list of node errors.
enum TezartNodeErrorTypes {
  /// Already revealed public key.
  ///
  /// Happens when trying to reveal an already revealed key.
  alreadyRevealedKey,

  /// Operation monitoring timedout.
  ///
  /// Happens when the monitoring of an operation times out :
  /// - time between two blocks exceeded the limit.
  /// - waited for too much blocks without retrieving the operation id.
  monitoringTimedOut,

  /// Counter already used error.
  ///
  /// Happens when the counter of an operation has already been used.
  counterError,

  /// Unhandled error.
  unhandled,
}

/// Exception thrown when an error occurs during an RPC node call.
///
/// You can translate the error messages using [key] or [type].
///
/// ```dart
/// try {
///   await RpcFailingCall();
/// } on TezartNodeError catch (e) {
///   print(e.message); // "You're trying to reveal an already revealed key."
///   print(e.key); // 'alreadyRevealedKey'
/// }
class TezartNodeError extends CommonException {
  final TezartHttpError cause;
  final TezartNodeErrorTypes _inputType;
  final String _inputMessage;
  final Map<String, String> metadata;

  final staticErrorsMessages = {
    TezartNodeErrorTypes.alreadyRevealedKey: "You're trying to reveal an already revealed key.",
    TezartNodeErrorTypes.counterError: 'A counter error occured',
    TezartNodeErrorTypes.unhandled: 'Unhandled error',
  };

  final dynamicErrorMessages = {
    TezartNodeErrorTypes.monitoringTimedOut: (String operationId) => 'Monitoring the operation $operationId timed out',
  };

  /// Default constructor.
  ///
  /// - [type] is required.
  /// - [message] is optional. If provided, it will be used.
  ///     If not, it will use `staticErrorMessages[type]` or `dynamicErrorMessages[type]` (in this priority order).
  /// - [metadata] is optional and must include metadata used to compute the message.
  ///     example: `{ 'operationId': 'opId' }` for monitoring time out errors.
  TezartNodeError({@required TezartNodeErrorTypes type, String message, this.metadata})
      : _inputType = type,
        _inputMessage = message,
        cause = null;

  /// Named constructor to construct [TezartNodeError] by passing a [TezartHttpError] object.
  TezartNodeError.fromHttpError(this.cause)
      : _inputType = null,
        _inputMessage = null,
        metadata = null;

  /// Type of this.
  TezartNodeErrorTypes get type => _inputType ?? _computedType;

  /// Human readable explanation of this.
  @override
  String get message => _inputMessage ?? _computedMessage;

  TezartNodeErrorTypes get _computedType {
    if (RegExp(r'Counter.*already used.*').hasMatch(_errorMsg)) {
      return TezartNodeErrorTypes.counterError;
    }

    if (RegExp(r'previously_revealed_key').hasMatch(_errorId)) {
      return TezartNodeErrorTypes.alreadyRevealedKey;
    }

    return TezartNodeErrorTypes.unhandled;
  }

  // TODO: what to do when there is multiple errors ?
  String get _errorId => cause?.responseBody?.first['id'] ?? '';
  String get _errorMsg => cause?.responseBody?.first['msg'] ?? '';

  /// String representation of type.
  @override
  String get key => EnumUtil.enumToString(type);

  String get _computedMessage {
    if (staticErrorsMessages.containsKey(type)) {
      return staticErrorsMessages[type];
    }

    switch (type) {
      case TezartNodeErrorTypes.monitoringTimedOut:
        {
          return dynamicErrorMessages[type](metadata.fetch<String>('operationId'));
        }
        break;
      default:
        {
          throw UnimplementedError('Unimplemented error type $type');
        }
        break;
    }
  }

  /// Cause of this, might be null.
  ///
  /// It represents the error that caused this.
  @override
  TezartHttpError get originalException => cause;
}