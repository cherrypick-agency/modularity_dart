import 'package:injectable/injectable.dart';

/// Name of the environment flag that marks dependencies as exportable
/// from a module's public scope.
///
/// Annotate injectable registrations with this environment to include them
/// in `Module.exports`:
///
/// ```dart
/// @Environment(modularityExportEnvName)
/// @LazySingleton(as: AuthService)
/// class AuthServiceImpl implements AuthService { ... }
/// ```
const modularityExportEnvName = 'modularity_export';

/// Annotation constant for teams that prefer `@modularityExportEnv` syntax
/// over `@Environment(modularityExportEnvName)`.
///
/// ```dart
/// @modularityExportEnv
/// @LazySingleton(as: AuthService)
/// class AuthServiceImpl implements AuthService { ... }
/// ```
const modularityExportEnv = Environment(modularityExportEnvName);

/// [EnvironmentFilter] that passes only dependencies annotated with
/// [modularityExportEnv] (or `@Environment(modularityExportEnvName)`).
///
/// Used internally by [ModularityInjectableBridge.configureExports] to ensure
/// that only export-marked registrations are written to the public scope.
class ModularityExportOnly extends EnvironmentFilter {
  /// Creates a filter that only allows [modularityExportEnv]-annotated
  /// dependencies.
  const ModularityExportOnly() : super(const {modularityExportEnvName});

  @override
  bool canRegister(Set<String> depEnvironments) {
    if (depEnvironments.isEmpty) {
      return false;
    }
    return depEnvironments.contains(modularityExportEnvName);
  }
}
