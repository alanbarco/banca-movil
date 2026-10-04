import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/sdui/home_section.dart';
import '../../core/sdui/section_registry.dart';
import 'accounts_routes.dart';
import 'data/datasources/accounts_firestore_datasource.dart';
import 'data/datasources/last_sync_store.dart';
import 'data/repositories/accounts_repository_impl.dart';
import 'domain/repositories/accounts_repository.dart';
import 'domain/usecases/fetch_more_movements.dart';
import 'domain/usecases/watch_account.dart';
import 'domain/usecases/watch_accounts.dart';
import 'domain/usecases/watch_recent_movements.dart';
import 'presentation/bloc/account_detail_cubit.dart';
import 'presentation/bloc/accounts_cubit.dart';
import 'presentation/bloc/movements_bloc.dart';
import 'presentation/widgets/accounts_summary_section.dart';

class AccountsModule extends FeatureModule {
  const AccountsModule();

  @override
  void register(GetIt getIt) {
    getIt
      ..registerLazySingleton(
        () => AccountsFirestoreDatasource(FirebaseFirestore.instance),
      )
      ..registerLazySingleton(() => LastSyncStore(getIt()))
      ..registerLazySingleton<AccountsRepository>(
        () => AccountsRepositoryImpl(
          datasource: getIt(),
          lastSync: getIt(),
          faults: getIt(),
          observability: getIt(),
        ),
      )
      ..registerLazySingleton(() => WatchAccounts(getIt()))
      ..registerLazySingleton(() => WatchAccount(getIt()))
      ..registerLazySingleton(() => WatchRecentMovements(getIt()))
      ..registerLazySingleton(() => FetchMoreMovements(getIt()))
      ..registerFactory(
        () => AccountsCubit(
          watchAccounts: getIt(),
          currentUser: getIt(),
          connectivity: getIt(),
          observability: getIt(),
        ),
      )
      ..registerFactoryParam<AccountDetailCubit, String, void>(
        (accountId, _) => AccountDetailCubit(
          accountId: accountId,
          watchAccount: getIt(),
          currentUser: getIt(),
          connectivity: getIt(),
          observability: getIt(),
        ),
      )
      ..registerFactoryParam<MovementsBloc, String, void>(
        (accountId, _) => MovementsBloc(
          accountId: accountId,
          watchRecentMovements: getIt(),
          fetchMoreMovements: getIt(),
          currentUser: getIt(),
          connectivity: getIt(),
          observability: getIt(),
        ),
      );

    getIt<SectionRegistry>().register(
      HomeSectionType.accountsSummary,
      (context, section) => BlocProvider(
        create: (_) => getIt<AccountsCubit>()..start(),
        child: const AccountsSummarySection(),
      ),
    );
  }

  @override
  List<RouteBase> get shellRoutes => accountsShellRoutes();
}
