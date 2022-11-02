import 'dart:math';

import 'package:tezart/src/models/operation/impl/operation_visitor.dart';
import 'package:tezart/tezart.dart';

class OperationHardLimitsSetterVisitor implements OperationVisitor {
  @override
  Future<void> visit(Operation operation) async {
    operation.storageLimit =
        operation.customStorageLimit ?? await _storage(operation);
    operation.gasLimit = operation.customGasLimit ?? await _gas(operation);
  }

  Future<int> _storage(Operation operation) async {
    final hardStorageLimitPerOperation = int.parse(
        (await _operationList(operation)
            .getConstants())['hard_storage_limit_per_operation'] as String);
    final sourceBalanceStorageLimitation =
        await _operationList(operation).rpcInterface.balance(operation.source);

    return min(hardStorageLimitPerOperation, sourceBalanceStorageLimitation);
  }

  Future<int> _gas(Operation operation) async {
    final blockGasLimit = int.parse((await _operationList(operation)
        .getConstants())['hard_gas_limit_per_block'] as String);
    final operationGasLimit = int.parse((await _operationList(operation)
        .getConstants())['hard_gas_limit_per_operation'] as String);
    final gasLimit = min(
        blockGasLimit ~/ _operationList(operation).operations.length,
        operationGasLimit);

    return gasLimit;
  }

  OperationsList _operationList(Operation operation) {
    final operationsList = operation.operationsList;
    if (operationsList == null) throw ArgumentError.notNull('operationsList');

    return operationsList;
  }
}
