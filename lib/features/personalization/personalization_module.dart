import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'personalization_routes.dart';

class PersonalizationModule extends FeatureModule {
  const PersonalizationModule();

  @override
  void register(GetIt sl) {}

  @override
  List<RouteBase> get shellRoutes => personalizationShellRoutes();
}
