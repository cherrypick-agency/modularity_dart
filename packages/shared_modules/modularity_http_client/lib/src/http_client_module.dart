import 'dart:async';

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:modularity_contracts/modularity_contracts.dart';

import 'http_client_module_config.dart';
import 'http_client_registry.dart';

/// Module for managing HTTP clients with named client support.
///
/// This module provides:
/// - Multiple named HTTP clients via [HttpClientRegistry]
/// - Default client accessible as [HttpClient]
/// - Automatic initialization and disposal of clients
///
/// ## Usage
///
/// ```dart
/// ModuleScope(
///   module: HttpClientModule(),
///   args: HttpClientModuleConfig(
///     clients: [
///       NamedHttpClientConfig(
///         name: 'api',
///         clientFactory: () => DioHttpClient(
///           config: DioHttpClientConfig(
///             baseUrl: Uri.parse('https://api.example.com'),
///           ),
///         ),
///         isDefault: true,
///       ),
///       NamedHttpClientConfig(
///         name: 'cdn',
///         clientFactory: () => DioHttpClient(
///           config: DioHttpClientConfig(
///             baseUrl: Uri.parse('https://cdn.example.com'),
///           ),
///         ),
///       ),
///     ],
///   ),
///   child: MyApp(),
/// )
/// ```
///
/// ## Accessing clients
///
/// ```dart
/// // Get default client
/// final client = binder.get<HttpClient>();
///
/// // Get client by name
/// final api = binder.get<HttpClientRegistry>().get('api');
/// final cdn = binder.get<HttpClientRegistry>().get('cdn');
/// ```
class HttpClientModule extends Module
    implements Configurable<HttpClientModuleConfig> {
  late HttpClientModuleConfig _config;
  final HttpClientRegistry _registry = HttpClientRegistry();

  @override
  void configure(HttpClientModuleConfig config) {
    config.validate();
    _config = config;
  }

  @override
  void binds(Binder i) {
    // No private bindings needed
  }

  @override
  void exports(Binder i) {
    // Export registry for named client access
    i.registerSingleton<HttpClientRegistry>(_registry);

    // Export default client for simple access via binder.get<HttpClient>()
    i.registerLazySingleton<HttpClient>(() => _registry.defaultClient);
  }

  @override
  Future<void> onInit() async {
    // Create and initialize all clients
    for (final clientConfig in _config.clients) {
      final client = clientConfig.clientFactory();
      await client.initialize();
      _registry.register(
        clientConfig.name,
        client,
        isDefault: clientConfig.isDefault,
      );
    }
  }

  @override
  void onDispose() {
    // Module.onDispose is synchronous, but client disposal is async.
    // Use unawaited to avoid blocking.
    unawaited(_registry.disposeAll());
  }
}
