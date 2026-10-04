import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/sdui/home_section.dart';
import '../../core/sdui/section_registry.dart';
import 'data/datasources/home_layout_remote_config_datasource.dart';
import 'data/repositories/home_layout_repository_impl.dart';
import 'domain/repositories/home_layout_repository.dart';
import 'domain/usecases/find_offer.dart';
import 'domain/usecases/resolve_home_layout.dart';
import 'personalization_routes.dart';
import 'presentation/bloc/home_layout_cubit.dart';
import 'presentation/widgets/banner_section.dart';
import 'presentation/widgets/offer_carousel_section.dart';
import 'presentation/widgets/quick_actions_section.dart';
import 'presentation/widgets/tip_section.dart';

class PersonalizationModule extends FeatureModule {
  const PersonalizationModule();

  @override
  void register(GetIt getIt) {
    getIt
      ..registerLazySingleton(() => HomeLayoutRemoteConfigDatasource(getIt()))
      ..registerLazySingleton<HomeLayoutRepository>(
        () => HomeLayoutRepositoryImpl(
          datasource: getIt(),
          faults: getIt(),
          observability: getIt(),
        ),
      )
      ..registerLazySingleton(() => ResolveHomeLayout(getIt()))
      ..registerLazySingleton(() => FindOffer(getIt()))
      ..registerFactory(
        () => HomeLayoutCubit(
          repository: getIt(),
          resolveHomeLayout: getIt(),
          currentUser: getIt(),
          flags: getIt(),
          observability: getIt(),
          canRender: getIt<SectionRegistry>().isRegistered,
        ),
      );

    getIt<SectionRegistry>()
      ..register(
        HomeSectionType.banner,
        (context, section) => BannerSection(section: section),
      )
      ..register(
        HomeSectionType.offerCarousel,
        (context, section) => OfferCarouselSection(section: section),
      )
      ..register(
        HomeSectionType.quickActions,
        (context, section) => QuickActionsSection(section: section),
      )
      ..register(
        HomeSectionType.tip,
        (context, section) => TipSection(section: section),
      );
  }

  @override
  List<RouteBase> get shellRoutes => personalizationShellRoutes();
}
