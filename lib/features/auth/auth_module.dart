import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/session/current_user_profile.dart';
import '../../core/session/session_status.dart';
import 'auth_routes.dart';
import 'data/datasources/customer_provisioning_datasource.dart';
import 'data/datasources/firebase_auth_datasource.dart';
import 'data/datasources/onboarding_seed_datasource.dart';
import 'data/datasources/user_profile_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/register_customer.dart';
import 'domain/usecases/send_password_reset.dart';
import 'domain/usecases/sign_in.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/update_interests.dart';
import 'domain/usecases/watch_auth_state.dart';
import 'presentation/bloc/auth_bloc.dart';

class AuthModule extends FeatureModule {
  const AuthModule();

  @override
  void register(GetIt getIt) {
    getIt
      ..registerLazySingleton(FirebaseAuthDatasource.new)
      ..registerLazySingleton(
        () => UserProfileDatasource(FirebaseFirestore.instance),
      )
      ..registerLazySingleton(
        () => CustomerProvisioningDatasource(FirebaseFirestore.instance),
      )
      ..registerLazySingleton(() => OnboardingSeedDatasource(getIt()))
      ..registerLazySingleton(
        () => AuthRepositoryImpl(
          auth: getIt(),
          profiles: getIt(),
          provisioning: getIt(),
          seeds: getIt(),
          sessionEvents: getIt(),
          observability: getIt(),
        ),
      )
      // Una sola instancia expuesta con dos contratos.
      ..registerLazySingleton<AuthRepository>(() => getIt<AuthRepositoryImpl>())
      ..registerLazySingleton<CurrentUserProfile>(
        () => getIt<AuthRepositoryImpl>(),
      )
      ..registerLazySingleton(() => SignIn(getIt()))
      ..registerLazySingleton(() => SignOut(getIt()))
      ..registerLazySingleton(() => RegisterCustomer(getIt()))
      ..registerLazySingleton(() => SendPasswordReset(getIt()))
      ..registerLazySingleton(() => WatchAuthState(getIt()))
      ..registerLazySingleton(() => UpdateInterests(getIt()))
      ..registerLazySingleton(
        () => AuthBloc(
          watchAuthState: getIt(),
          signOut: getIt(),
          sessionTimeout: getIt(),
          storage: getIt(),
          observability: getIt(),
        ),
      )
      ..registerLazySingleton<SessionStatusSource>(() => getIt<AuthBloc>());
  }

  @override
  List<RouteBase> get routes => authRoutes();

  @override
  List<RouteBase> get shellRoutes => authShellRoutes();
}
