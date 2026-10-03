import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity/connectivity_cubit.dart';
import '../core/fault_injection/fault_injection_cubit.dart';
import '../core/ui/balance_visibility_cubit.dart';
import '../core/ui/theme.dart';
import '../core/ui/widgets/offline_banner.dart';
import 'di.dart';

class BiApp extends StatelessWidget {
  const BiApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final faults = sl<FaultInjectionCubit>();
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: faults),
        BlocProvider.value(value: sl<ConnectivityCubit>()),
        BlocProvider(create: (_) => BalanceVisibilityCubit(sl())),
      ],
      child: MaterialApp.router(
        title: 'BI App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('es', 'EC'),
        supportedLocales: const [Locale('es', 'EC'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) =>
            OfflineAwareLayout(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Muestra el banner offline sobre cualquier pantalla (incluidas login y
/// splash), no solo dentro del shell.
class OfflineAwareLayout extends StatelessWidget {
  const OfflineAwareLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offline = context.select<ConnectivityCubit, bool>(
      (cubit) => !cubit.state.isOnline,
    );
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          // El banner ya ocupa la barra de estado.
          child: offline
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                )
              : child,
        ),
      ],
    );
  }
}
