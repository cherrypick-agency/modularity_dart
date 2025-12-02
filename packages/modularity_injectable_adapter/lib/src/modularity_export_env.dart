import 'package:injectable/injectable.dart';

/// Name of the environment flag that marks dependencies as exportable.
const modularityExportEnvName = 'modularity_export';

/// Environment used to tag dependencies that should be exported outside a module.
const modularityExportEnv = Environment(modularityExportEnvName);

/// Filters injectable registrations so that only dependencies annotated with
/// [modularityExportEnv] are processed.
class ModularityExportOnly extends EnvironmentFilter {
  const ModularityExportOnly() : super(const {modularityExportEnvName});

  @override
  bool canRegister(Set<String> depEnvironments) {
    if (depEnvironments.isEmpty) {
      return false;
    }
    return depEnvironments.contains(modularityExportEnvName);
  }
}
