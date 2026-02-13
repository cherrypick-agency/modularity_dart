import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modularity_flutter/modularity_flutter.dart';
import 'modules/home/home_module.dart';

final _observer = RouteObserver<ModalRoute<dynamic>>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ModularityRoot(
      observer: _observer,
      lifecycleLogger: kDebugMode ? ModularityRoot.defaultDebugLogger : null,
      child: MaterialApp(
        title: 'Complex Modularity App',
        navigatorObservers: [_observer],
        theme: ThemeData(primarySwatch: Colors.blue),
        home: ModuleScope(module: HomeModule(), child: const HomePage()),
      ),
    );
  }
}
