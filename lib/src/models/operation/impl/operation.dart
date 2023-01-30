import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:tezart/src/common/utils/enum_util.dart';
import 'package:tezart/src/common/validators/simulation_result_validator.dart';
import 'package:tezart/src/crypto/crypto.dart' as crypto hide Prefixes;
import 'package:tezart/src/models/operation/impl/operation_visitor.dart';
import 'package:tezart/tezart.dart';

part 'operation.g.dart';

enum Kinds {
  generic,
  transaction,
  delegation,
  origination,
  transfer,
  reveal,
}

/// A class representing a single tezos operation
@JsonSerializable(includeIfNull: false, createFactory: false)
class Operation {
  @JsonKey(ignore: true)
  Map<String, dynamic>? _simulationResult;
  @JsonKey(ignore: true)
  OperationsList? operationsList;
  @JsonKey(ignore: true)
  final log = Logger('Operation');

  @JsonKey(toJson: _kindToString)
  final Kinds kind;

  @JsonKey()
  final String? destination;

  @JsonKey(toJson: _toString)
  final int? amount;

  @JsonKey(toJson: _toString)
  final int? balance;

  @JsonKey(toJson: _toString)
  int? counter;

  @JsonKey(ignore: true)
  dynamic? params;

  @JsonKey(ignore: true)
  String? entrypoint;

  @JsonKey()
  Map<String, dynamic>? script;

  @JsonKey(name: 'gas_limit', toJson: _toString)
  int? gasLimit;
  @JsonKey(toJson: _toString)
  int fee;
  @JsonKey(ignore: true)
  final int? customFee;
  @JsonKey(name: 'storage_limit', toJson: _toString)
  int? storageLimit;
  @JsonKey(ignore: true)
  int? customGasLimit;
  @JsonKey(ignore: true)
  int? customStorageLimit;

  @JsonKey(ignore: true)
  int totalFee = 0;

  Operation({
    required this.kind,
    this.amount,
    this.balance,
    this.destination,
    this.params,
    this.script,
    this.customFee,
    this.entrypoint,
    this.customGasLimit,
    this.customStorageLimit,
  }) : fee = 0;

  @JsonKey()
  String get source {
    if (operationsList == null) throw ArgumentError.notNull('operationsList');

    final publicKey = operationsList!.publicKey;
    return crypto.addressFromPublicKey(publicKey);
  }

  @JsonKey()
  Map<String, dynamic>? get parameters {
    var result = <String, dynamic>{};
    if (entrypoint != null) result['entrypoint'] = entrypoint;
    if (params != null) result['value'] = params;

    return result.keys.isEmpty ? null : result;
  }

  @JsonKey(name: 'public_key')
  String? get publicKey => kind == Kinds.reveal
      ? operationsList?.publicKey ?? operationsList?.source?.publicKey
      : null;

  Map<String, dynamic> toJson() => _$OperationToJson(this);

  factory Operation.fromJson(Map<String, dynamic> map) {
    final String? kind = map["kind"];
    final String? storageLimit = map["storageLimit"];
    final String? gasLimit = map["gasLimit"];
    final String? fee = map["fee"];

    if (kind == "origination") {
      final String balance = map["balance"] ?? "0";
      final List<dynamic> code = map["code"];
      final dynamic storage = map["storage"];

      final operation = OriginationOperation(
        balance: int.parse(balance),
        code: code.map((e) => Map<String, dynamic>.from(e)).toList(),
        storage: storage,
        customFee: fee != null ? int.parse(fee) : null,
        customGasLimit: gasLimit != null ? int.parse(gasLimit) : null,
        customStorageLimit:
            storageLimit != null ? int.parse(storageLimit) : null,
      );
      return operation;
    } else {
      final int amount = int.tryParse(map["amount"].toString()) ?? 0;
      final String destination = map["destination"] ?? "";
      final dynamic parameters = map["parameters"] != null
          ? json.decode(json.encode(map["parameters"]))
          : null;
      final String? entrypoint = map["entrypoint"];
      final operation = TransactionOperation(
        amount: amount,
        destination: destination,
        entrypoint: entrypoint,
        params: parameters,
        customFee: int.tryParse(fee ?? ""),
        customGasLimit: int.tryParse(gasLimit ?? ""),
        customStorageLimit:
            storageLimit != null ? int.parse(storageLimit) : null,
      );
      return operation;
    }
  }

  static String? _toString(int? integer) => integer?.toString();

  static String _kindToString(Kinds kind) => EnumUtil.enumToString(kind);

  set simulationResult(Map<String, dynamic>? value) {
    if (value == null) throw ArgumentError.notNull('simulationResult');

    _simulationResult = value;
    SimulationResultValidator(_simulationResult!).validate();
  }

  @JsonKey(ignore: true)
  Map<String, dynamic>? get simulationResult => _simulationResult;

  Future<void> setLimits(OperationVisitor visitor) async {
    await visitor.visit(this);
  }
}
