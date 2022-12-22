import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tezart/tezart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _fee = '-';
  final _tezartClient = TezartClient("https://ithacanet.ecadinfra.com");

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    final keystore = Keystore.fromSecretKey("secret-key");

    final operation = await _tezartClient.transferOperation(
      source: keystore,
      publicKey: keystore.publicKey,
      destination: "tz1L76GWnRL8ottK7veac96JPuArFLEhZeVa",
      amount: 300,
      reveal: true,
    );
    await operation.estimate();
    final fee = operation.operations
        .map((e) => e.fee)
        .reduce((value, element) => value + element);

    setState(() {
      _fee = "$fee";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Fee estimated: $_fee'),
        ),
      ),
    );
  }
}
