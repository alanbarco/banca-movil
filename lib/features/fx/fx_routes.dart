import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import 'presentation/bloc/fx_cubit.dart';
import 'presentation/pages/fx_page.dart';

final _getIt = GetIt.instance;

/// `/fx` (pestaña Divisas). El flag `fx_service` lo aplica el `redirect`
/// global.
List<RouteBase> fxShellRoutes() => [
  GoRoute(
    path: AppRoutes.fx,
    builder: (context, state) => BlocProvider(
      create: (_) => _getIt<FxCubit>()..load(),
      child: const FxPage(),
    ),
  ),
];
