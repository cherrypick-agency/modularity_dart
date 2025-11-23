// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i6;
import 'package:example_auto_route/modules/auth/auth_module.dart' as _i1;
import 'package:example_auto_route/modules/dashboard/dashboard_module.dart'
    as _i2;
import 'package:example_auto_route/modules/details/details_module.dart' as _i3;
import 'package:example_auto_route/modules/home/home_module.dart' as _i4;
import 'package:example_auto_route/modules/settings/settings_module.dart'
    as _i5;

/// generated route for
/// [_i1.AuthPage]
class AuthRoute extends _i6.PageRouteInfo<void> {
  const AuthRoute({List<_i6.PageRouteInfo>? children})
    : super(AuthRoute.name, initialChildren: children);

  static const String name = 'AuthRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i1.AuthPage();
    },
  );
}

/// generated route for
/// [_i2.DashboardPage]
class DashboardRoute extends _i6.PageRouteInfo<void> {
  const DashboardRoute({List<_i6.PageRouteInfo>? children})
    : super(DashboardRoute.name, initialChildren: children);

  static const String name = 'DashboardRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i2.DashboardPage();
    },
  );
}

/// generated route for
/// [_i3.DetailsPage]
class DetailsRoute extends _i6.PageRouteInfo<DetailsRouteArgs> {
  DetailsRoute({required String id, List<_i6.PageRouteInfo>? children})
    : super(
        DetailsRoute.name,
        args: DetailsRouteArgs(id: id),
        initialChildren: children,
      );

  static const String name = 'DetailsRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DetailsRouteArgs>();
      return _i3.DetailsPage(id: args.id);
    },
  );
}

class DetailsRouteArgs {
  const DetailsRouteArgs({required this.id});

  final String id;

  @override
  String toString() {
    return 'DetailsRouteArgs{id: $id}';
  }
}

/// generated route for
/// [_i4.HomePage]
class HomeRoute extends _i6.PageRouteInfo<void> {
  const HomeRoute({List<_i6.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i4.HomePage();
    },
  );
}

/// generated route for
/// [_i5.SettingsPage]
class SettingsRoute extends _i6.PageRouteInfo<void> {
  const SettingsRoute({List<_i6.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i6.PageInfo page = _i6.PageInfo(
    name,
    builder: (data) {
      return const _i5.SettingsPage();
    },
  );
}
