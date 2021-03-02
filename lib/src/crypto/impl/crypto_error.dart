import 'package:meta/meta.dart';
import 'package:tezart/src/common/exceptions/common_exception.dart';
import 'package:tezart/src/common/utils/enum_util.dart';

enum CryptoErrorTypes {
  prefixNotFound,
  unknownPrefix,
  seedBytesLengthError,
  seedLengthError,
  secretKeyLengthError,
  invalidMnemonic,
  invalidChecksum,
  invalidHexDataLength,
  invalidHex,
  unhandled,
}

/// Exception thrown when an error occurs during crypto operation.
class CryptoError extends CommonException {
  final CryptoErrorTypes _inputType;
  final String _inputMessage;
  final dynamic cause;

  final staticErrorsMessages = {
    CryptoErrorTypes.prefixNotFound: 'Prefix not found',
    CryptoErrorTypes.unknownPrefix: 'Unknown prefix',
    CryptoErrorTypes.seedBytesLengthError: 'The seed must be 32 bytes long',
    CryptoErrorTypes.seedLengthError: 'The seed must be 54 characters long',
    CryptoErrorTypes.secretKeyLengthError: 'The secret key must 98 characters long',
    CryptoErrorTypes.invalidMnemonic: 'The mnemonic is invalid',
    CryptoErrorTypes.invalidChecksum: 'Invalid checksum',
    CryptoErrorTypes.invalidHexDataLength: "Hexadecimal data's length must be even",
    CryptoErrorTypes.invalidHex: 'Invalid hexadecimal',
  };
  final dynamicErrorMessages = {
    CryptoErrorTypes.unhandled: (dynamic e) => 'Unhandled error: $e',
  };

  CryptoError({@required CryptoErrorTypes type, String message, this.cause})
      : _inputType = type,
        _inputMessage = message;

  CryptoErrorTypes get type => _inputType;

  @override
  String get message => _inputMessage ?? _computedMessage;

  String get _computedMessage {
    if (staticErrorsMessages.containsKey(type)) return staticErrorsMessages[type];

    switch (type) {
      case CryptoErrorTypes.unhandled:
        return dynamicErrorMessages[type](cause);

        break;
      default:
        throw UnimplementedError('Unimplemented error type $type');

        break;
    }
  }

  @override
  String get key => EnumUtil.enumToString(type);

  @override
  dynamic get originalException => cause;
}

T catchUnhandledErrors<T>(T Function() func) {
  try {
    return func();
  } catch (e) {
    if (e is CryptoError) rethrow;
    throw CryptoError(type: CryptoErrorTypes.unhandled, cause: e);
  }
}