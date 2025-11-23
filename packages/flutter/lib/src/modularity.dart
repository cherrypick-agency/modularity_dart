import 'package:flutter/widgets.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

/// Global configuration and helpers for Modularity.
class Modularity {
  /// Global RouteObserver for Retention Policy.
  static final RouteObserver<ModalRoute> observer = RouteObserver<ModalRoute>();
  
  /// Global list of ModuleInterceptors.
  static final List<ModuleInterceptor> interceptors = [];
}
