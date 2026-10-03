import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/routing/app_routes.dart';
import '../../core/session/current_user_profile.dart';
import 'presentation/pages/home_page.dart';

class PersonalizationModule extends FeatureModule {
  const PersonalizationModule();

  @override
  void register(GetIt sl) {}

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) =>
          HomePage(currentUser: GetIt.instance<CurrentUserProfile>()),
    ),
  ];
}
