import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'data/datasources/fx_local_cache.dart';
import 'data/datasources/fx_remote_datasource.dart';
import 'data/repositories/fx_repository_impl.dart';
import 'domain/repositories/fx_repository.dart';
import 'fx_routes.dart';
import 'presentation/bloc/fx_cubit.dart';

class FxModule extends FeatureModule {
  const FxModule();

  @override
  void register(GetIt getIt) {
    getIt
      ..registerLazySingleton(
        () => FxRemoteDatasource(dioFactory: getIt(), remoteConfig: getIt()),
      )
      ..registerLazySingleton(() => FxLocalCache(getIt()))
      ..registerLazySingleton<FxRepository>(
        () => FxRepositoryImpl(
          remote: getIt(),
          cache: getIt(),
          observability: getIt(),
        ),
      )
      ..registerFactory(() => FxCubit(repository: getIt()));
  }

  @override
  List<RouteBase> get shellRoutes => fxShellRoutes();
}
