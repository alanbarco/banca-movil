import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import 'presentation/bloc/account_detail_cubit.dart';
import 'presentation/bloc/movements_bloc.dart';
import 'presentation/pages/account_detail_page.dart';

final _getIt = GetIt.instance;

/// `/accounts/:accountId`. Va dentro del shell para que la actividad en el
/// detalle también reinicie el temporizador de inactividad (FR-007).
List<RouteBase> accountsShellRoutes() => [
  GoRoute(
    path: AppRoutes.accountDetail,
    builder: (context, state) {
      final accountId = state.pathParameters['accountId']!;
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                _getIt<AccountDetailCubit>(param1: accountId)..start(),
          ),
          BlocProvider(
            create: (_) =>
                _getIt<MovementsBloc>(param1: accountId)
                  ..add(const MovementsStarted()),
          ),
        ],
        child: const AccountDetailPage(),
      );
    },
  ),
];
