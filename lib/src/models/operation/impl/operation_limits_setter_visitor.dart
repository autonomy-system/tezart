import 'package:tezart/src/core/rpc/impl/rpc_interface.dart';
import 'package:tezart/src/models/operation/impl/operation_visitor.dart';
import 'package:tezart/src/models/operation/operation.dart';

import 'operation.dart';

class OperationLimitsSetterVisitor implements OperationVisitor {
  static const _gasBuffer = 500;

  @override
  Future<void> visit(Operation operation) async {
    final originationDefaultSize = await _originationDefaultSize(operation);
    operation.gasLimit = operation.customGasLimit ?? _gasLimitFromConsumed(operation);
    operation.storageLimit = operation.customStorageLimit ?? _simulationStorageSize(operation, originationDefaultSize: originationDefaultSize);

    if (operation.customStorageLimit != null) return;

    if (operation.kind == Kinds.origination || _isDestinationContractAllocated(operation)) {
      operation.storageLimit = operation.storageLimit! + originationDefaultSize;
    }
  }

  // returns true if the operation is a transfer to an address unknown by the chain
  bool _isDestinationContractAllocated(Operation operation) {
    return _simulationResult(operation)['metadata']['operation_result']['allocated_destination_contract'] == true;
  }

  int _simulationStorageSize(Operation operation, {int originationDefaultSize = 257 }) {
    final List internalOperationResults = _simulationResult(operation)['metadata']['internal_operation_results'];
    var storageSize = int.parse(_simulationResult(operation)['metadata']['operation_result']['paid_storage_size_diff'] ?? '0');
    var totalAllocationStorage = 0;

    internalOperationResults.forEach((element) {
      storageSize += int.parse(element['result']['paid_storage_size_diff'] ?? '0');
      if (element['kind'] == 'origination' || element['result']['allocated_destination_contract'] == true)
        totalAllocationStorage += originationDefaultSize;
    });

    return storageSize + totalAllocationStorage;
  }

  int _gasLimitFromConsumed(Operation operation) {
    return (_simulationConsumedGas(operation) + _gasBuffer);
  }

  int _simulationConsumedGas(Operation operation) {
    final List internalOperationResults = _simulationResult(operation)['metadata']['internal_operation_results'];
    var totalGas = int.parse(_simulationResult(operation)['metadata']['operation_result']['consumed_gas'] ?? '0');

    internalOperationResults.forEach((element) {
      totalGas += int.parse(element['result']['consumed_gas'] ?? '0');
    });

    return totalGas;
  }

  Future<int> _originationDefaultSize(Operation operation) async {
    return (await _rpcInterface(operation).constants())['origination_size'];
  }

  Map<String, dynamic> _simulationResult(Operation operation) {
    if (operation.simulationResult == null) throw ArgumentError.notNull('operation.simulationResult');

    return operation.simulationResult!;
  }

  RpcInterface _rpcInterface(Operation operation) {
    if (operation.operationsList == null) throw ArgumentError.notNull('operation.operationsList');

    return operation.operationsList!.rpcInterface;
  }
}
