library modularity_flutter;

export 'package:modularity_core/modularity_core.dart';

export 'src/modularity.dart'
    show Modularity, ModuleLifecycleEvent, ModuleLifecycleLogger;
export 'src/retention/module_retainer.dart'
    show ModuleRetainer, ModuleRetainerEntrySnapshot;
export 'src/widgets/modularity_root.dart';
export 'src/widgets/module_provider.dart';
export 'src/widgets/module_scope.dart';
