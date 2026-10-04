import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/sdui/section_registry.dart';
import '../../core/session/current_user_profile.dart';
import 'domain/usecases/find_offer.dart';
import 'presentation/bloc/home_layout_cubit.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/offer_detail_page.dart';

final _getIt = GetIt.instance;

/// `/home` (pestaña) y `/offers/:offerId` (dentro del shell para que la
/// actividad reinicie el temporizador de inactividad). El flag `offers` lo
/// aplica el `redirect` global.
List<RouteBase> personalizationShellRoutes() => [
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => BlocProvider(
      create: (_) => _getIt<HomeLayoutCubit>()..start(),
      child: HomePage(sections: _getIt<SectionRegistry>()),
    ),
  ),
  GoRoute(
    path: AppRoutes.offerDetail,
    builder: (context, state) => OfferDetailPage(
      offer: _getIt<FindOffer>()(
        state.pathParameters['offerId']!,
        segment: _getIt<CurrentUserProfile>().current?.segment,
      ),
    ),
  ),
];
