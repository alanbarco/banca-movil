import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/sdui/section_registry.dart';
import '../../core/session/current_user_profile.dart';
import 'presentation/pages/home_page.dart';

final _getIt = GetIt.instance;

/// `/home` (pestaña del shell).
List<RouteBase> personalizationShellRoutes() => [
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => HomePage(
      currentUser: _getIt<CurrentUserProfile>(),
      sections: _getIt<SectionRegistry>(),
    ),
  ),
];
