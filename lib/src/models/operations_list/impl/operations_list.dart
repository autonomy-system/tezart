import 'package:logging/logging.dart';
import 'package:pinenacl/x25519.dart';
import 'package:retry/retry.dart';
import 'package:tezart/src/core/client/tezart_client.dart';
import 'package:tezart/src/core/rpc/rpc_interface.dart';
import 'package:tezart/src/crypto/crypto.dart' as crypto hide Prefixes;
import 'package:tezart/src/keystore/keystore.dart';
import 'package:tezart/src/models/operation/impl/operation_fees_setter_visitor.dart';
import 'package:tezart/src/models/operation/impl/operation_hard_limits_setter_visitor.dart';
import 'package:tezart/src/models/operation/impl/operation_limits_setter_visitor.dart';
import 'package:tezart/src/models/operation/operation.dart';
import 'package:tezart/src/models/operations_list/operations_list.dart';
import 'package:tezart/src/signature/signature.dart';

import 'operations_list_result.dart';

typedef SignCallback = Future<Uint8List> Function(String data);

/// A class that stores, simulates, estimates and broadcasts a list of [Operation]
///
/// - [operations] is the list of the operations of this
/// - [result] is an object that stores the results of the different steps of this
/// - [source] is the [Keystore] initiating the operations
/// - [rpcInterface] is the rpc interface that makes the calls to the tezos node
class OperationsList {
  final log = Logger('Operation');
  final List<Operation> operations = [];
  final result = OperationsListResult();
  final Keystore? source;
  final String publicKey;
  final RpcInterface rpcInterface;
  Map<String, dynamic>? _constants;

  OperationsList({this.source, required this.publicKey, required this.rpcInterface});

  /// Prepends [op] to this
  void prependOperation(Operation op) {
    op.operationsList = this;
    operations.insert(0, op);
  }

  /// Appends [op] to this
  void appendOperation(Operation op) {
    op.operationsList = this;
    operations.add(op);
  }

  /// Preapplies this
  ///
  /// It must be run after [sign] because it needs result.signature to be set
  /// It sets the simulationResult for all the elements of [operations]
  Future<void> preapply() async {
    await _catchHttpError<void>(() async {
      if (result.signature == null) throw ArgumentError.notNull('result.signature');

      final simulationResults = await rpcInterface.preapplyOperations(
        operationsList: this,
        signature: result.signature!.edsig,
      );

      for (var i = 0; i < simulationResults.length; i++) {
        operations[i].simulationResult = simulationResults[i];
      }
    });
  }

  /// Runs this
  ///
  /// Same as [preapply] but without signature check
  Future<void> run() async {
    await _catchHttpError<void>(() async {
      final simulationResults = await rpcInterface.runOperations(this);

      for (var i = 0; i < simulationResults.length; i++) {
        operations[i].simulationResult = simulationResults[i];
      }
    });
  }

  /// Forges this
  ///
  /// It sets result.forgedOperation
  Future<void> forge() async {
    await _catchHttpError<void>(() async {
      result.forgedOperation = await rpcInterface.forgeOperations(this);
    });
  }

  /// Signs this
  ///
  /// It sets result.signature\
  /// It must be run after [forge], because it needs result.forgedOperation to be set
  Future<void> sign(SignCallback? signCallback) async {
    if (result.forgedOperation == null) throw ArgumentError.notNull('result.forgedOperation');
    if (signCallback == null && source == null) throw ArgumentError.notNull('source or signCallback');

    if (signCallback != null) {
      final signature = await signCallback(result.forgedOperation!);
      result.signature = Signature.fromHexPreSign(
        data: result.forgedOperation!,
        signature: signature,
      );
    } else {
      result.signature = Signature.fromHex(
        data: result.forgedOperation!,
        keystore: source!,
        watermark: Watermarks.generic,
      );
    }
  }

  /// Injects this
  ///
  /// It must be run after [sign] because it needs result.signature to be set
  Future<void> inject() async {
    await _catchHttpError<void>(() async {
      if (result.signature == null) throw ArgumentError.notNull('result.signature');

      result.id = await rpcInterface
          .injectOperation(result.signature!.hexIncludingPayload);
    });
  }

  /// Waits for this to be executed and monitored
  ///
  /// It throws a [TezartNodeError] or a [TezartHttpError] if any error happens
  Future<void> executeAndMonitor(SignCallback? signCallback) async {
    await execute(signCallback);
    await monitor();
  }

  /// Executes this
  ///
  /// It runs [estimate], [simulate] and [broadcast] respectively
  Future<void> execute(SignCallback? signCallback) async {
    await _retryOnCounterError<void>(() async {
      await estimate();
      await broadcast(signCallback);
    });
  }

  /// Broadcasts this
  ///
  /// It runs [forge], [sign] and [inject] respectively
  Future<void> broadcast(SignCallback? signCallback) async {
    await forge();
    await sign(signCallback);
    await inject();
  }

  /// Estimates this
  ///
  /// It sets the counters of the different operations, and computes the limits and the fees of this
  Future<void> estimate({int? baseOperationCustomFee}) async {
    await computeCounters();
    await computeLimits();
    await computeFees(baseOperationCustomFee: baseOperationCustomFee);
  }

  /// Sets the limits of this
  Future<void> computeLimits() async {
    await setHardLimits();
    await simulate();
    await setLimits();
  }

  /// Simulates the execution of this using a preapply
  ///
  /// It throws an error if anything wrong happens
  Future<void> simulate() async {
    await forge();
    await run();
  }

  /// Computes and sets the counters of [operations]
  Future<void> computeCounters() async {
    // TODO: use expirable cache based on time between blocks so that we can
    // call this method before forge, sign, preapply and run
    await _catchHttpError<void>(() async {
      final firstOperation = operations.first;
      final address = crypto.addressFromPublicKey(publicKey);
      firstOperation.counter = await rpcInterface.counter(address) + 1;

      for (var i = 1; i < operations.length; i++) {
        operations[i].counter = operations[i - 1].counter! + 1;
      }
    });
  }

  /// It sets the limits of [operations] to the hard limits of the chain
  Future<void> setHardLimits() async {
    await Future.wait(operations.map((operation) async {
      await operation.setLimits(OperationHardLimitsSetterVisitor());
    }));
  }

  /// It sets the optimal limits of [operations]
  Future<void> setLimits() async {
    await Future.wait(operations.map((operation) async {
      await operation.setLimits(OperationLimitsSetterVisitor());
    }));

    // resimulate to check that limit computation is valid. Remove this in a stable version ??
    // await simulate();
  }

  /// It sets the optimal fees of [operations]
  ///
  /// The computation is based on the bakers default config.
  Future<void> computeFees({int? baseOperationCustomFee}) async {
    await Future.wait(operations.map((operation) async {
      await operation.setLimits(OperationFeesSetterVisitor(baseOperationCustomFee: baseOperationCustomFee));
    }));
  }

  /// Monitors this
  Future<void> monitor() async {
    if (result.id == null) throw ArgumentError.notNull('result.id');

    log.info('request to monitorOperation ${result.id}');
    final blockHash = await rpcInterface.monitorOperation(operationId: result.id!);
    result.blockHash = blockHash;
  }

  Future<Map<String, dynamic>> getConstants() async {
    _constants ??= await rpcInterface.constants();
    return _constants!;
  }

  Future<T> _catchHttpError<T>(Future<T> Function() func) {
    return catchHttpError<T>(func, onError: (TezartHttpError e) {
      log.severe('Http Error', e);
    });
  }

  Future<T> _retryOnCounterError<T>(func) {
    final r = RetryOptions(maxAttempts: 5);
    return r.retry<T>(
      func,
      retryIf: (e) => e is TezartNodeError && e.type == TezartNodeErrorTypes.counterError,
    );
  }
}
