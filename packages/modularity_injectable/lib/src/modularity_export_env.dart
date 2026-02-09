import 'package:injectable/injectable.dart';

/// Name of the environment flag that marks dependencies as exportable.
///
/// Use inside `env: [modularityExportEnvName]`.
const modularityExportEnvName = 'modularity_export';

/// Annotation helper for teams that prefer `@Environment(...)` syntax.
const modularityExportEnv = Environment(modularityExportEnvName);

/// Filters injectable registrations so that only dependencies annotated with
/// [modularityExportEnv] are processed.
class ModularityExportOnly extends EnvironmentFilter {
  /// Creates a filter that only allows [modularityExportEnv]-annotated deps.
  const ModularityExportOnly() : super(const {modularityExportEnvName});

  @override
  bool canRegister(Set<String> depEnvironments) {
    if (depEnvironments.isEmpty) {
      return false;
    }
    return depEnvironments.contains(modularityExportEnvName);
  }
}
