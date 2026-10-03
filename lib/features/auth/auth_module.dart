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
import 'domain/usecases/watch_auth_state.dart';
import 'presentation/bloc/auth_bloc.dart';

class AuthModule extends FeatureModule {
  const AuthModule();

  @override
  void register(GetIt sl) {
    sl
      ..registerLazySingleton(FirebaseAuthDatasource.new)
      ..registerLazySingleton(
        () => UserProfileDatasource(FirebaseFirestore.instance),
      )
      ..registerLazySingleton(
        () => CustomerProvisioningDatasource(FirebaseFirestore.instance),
      )
      ..registerLazySingleton(() => OnboardingSeedDatasource(sl()))
      ..registerLazySingleton(
        () => AuthRepositoryImpl(
          auth: sl(),
          profiles: sl(),
          provisioning: sl(),
          seeds: sl(),
          sessionEvents: sl(),
          observability: sl(),
        ),
      )
      // Una sola instancia expuesta con dos contratos.
      ..registerLazySingleton<AuthRepository>(() => sl<AuthRepositoryImpl>())
      ..registerLazySingleton<CurrentUserProfile>(
        () => sl<AuthRepositoryImpl>(),
      )
      ..registerLazySingleton(() => SignIn(sl()))
      ..registerLazySingleton(() => SignOut(sl()))
      ..registerLazySingleton(() => RegisterCustomer(sl()))
      ..registerLazySingleton(() => SendPasswordReset(sl()))
      ..registerLazySingleton(() => WatchAuthState(sl()))
      ..registerLazySingleton(
        () => AuthBloc(
          watchAuthState: sl(),
          signOut: sl(),
          sessionTimeout: sl(),
          storage: sl(),
          observability: sl(),
        ),
      )
      ..registerLazySingleton<SessionStatusSource>(() => sl<AuthBloc>());
  }

  @override
  List<RouteBase> get routes => authRoutes();

  @override
  List<RouteBase> get shellRoutes => authShellRoutes();
}
