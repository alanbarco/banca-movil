import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/flags/feature_flag_service.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../../../core/sdui/home_section.dart';
import '../../../../core/session/current_user_profile.dart';
import '../../domain/entities/home_layout.dart';
import '../../domain/repositories/home_layout_repository.dart';
import '../../domain/usecases/resolve_home_layout.dart';

class HomeLayoutState extends Equatable {
  const HomeLayoutState({
    this.loading = true,
    this.sections = const [],
    this.usedFallback = false,
    this.segment,
  });

  /// `true` hasta tener el primer layout (o el predeterminado).
  final bool loading;
  final List<HomeSection> sections;
  final bool usedFallback;
  final String? segment;

  @override
  List<Object?> get props => [loading, sections, usedFallback, segment];
}

/// Inicio del cliente: combina su perfil (segmento e intereses), el layout
/// del banco y los flags; re-emite ante cualquier cambio (FR-015, FR-018).
///
/// Si la personalización falla se conserva el último layout conocido o, si
/// no hay ninguno, se usan los defaults locales (escenario US3-6).
class HomeLayoutCubit extends Cubit<HomeLayoutState> {
  HomeLayoutCubit({
    required HomeLayoutRepository repository,
    required ResolveHomeLayout resolveHomeLayout,
    required CurrentUserProfile currentUser,
    required FeatureFlagService flags,
    required ObservabilityService observability,
    bool Function(HomeSectionType type)? canRender,
  }) : _repository = repository,
       _resolve = resolveHomeLayout,
       _currentUser = currentUser,
       _flags = flags,
       _observability = observability,
       _canRender = canRender,
       super(const HomeLayoutState());

  static const feature = 'personalization';

  final HomeLayoutRepository _repository;
  final ResolveHomeLayout _resolve;
  final CurrentUserProfile _currentUser;
  final FeatureFlagService _flags;
  final ObservabilityService _observability;
  final bool Function(HomeSectionType type)? _canRender;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Incidentes ya reportados, para no repetir el evento en cada re-emisión.
  final Set<String> _reported = {};

  HomeLayout? _layout;
  SessionUser? _user;

  void start() {
    _user = _currentUser.current;
    _subscriptions
      ..add(_repository.watchLayout().listen(_onLayout))
      ..add(
        _currentUser.user.listen((user) {
          _user = user;
          _render();
        }),
      )
      ..add(_flags.changes.listen((_) => _render()));
  }

  /// Pull-to-refresh: el nuevo layout llega por [HomeLayoutRepository.watchLayout].
  Future<void> refresh() async {
    final result = await _repository.refresh();
    if (result case Err(:final failure)) _logLoadError(failure);
  }

  void _onLayout(Result<HomeLayout> result) {
    switch (result) {
      case Success(:final value):
        _layout = value;
      case Err(:final failure):
        _logLoadError(failure);
        // Se mantiene el último layout; sin ninguno, el predeterminado.
        _layout ??= _repository.current ?? _repository.localDefaults;
    }
    _render();
  }

  void _render() {
    final layout = _layout;
    if (layout == null || isClosed) return;
    final user = _user;
    final home = _resolve(
      layout: layout,
      fallback: _repository.localDefaults,
      segment: user?.segment,
      interests: user?.interests ?? const [],
      canRender: _canRender,
    );
    for (final skipped in home.skipped) {
      if (!_reported.add('${skipped.id}|${skipped.type}|${skipped.reason}')) {
        continue;
      }
      unawaited(
        _observability.logEvent(AnalyticsEvents.sduiSectionSkipped, {
          AnalyticsParams.sectionType: skipped.type,
          AnalyticsParams.reason: skipped.reason,
        }),
      );
    }
    emit(
      HomeLayoutState(
        loading: false,
        sections: home.sections,
        usedFallback:
            home.usedFallback || identical(layout, _repository.localDefaults),
        segment: user?.segment,
      ),
    );
  }

  void _logLoadError(Failure failure) {
    unawaited(
      _observability.logEvent(AnalyticsEvents.dataLoadError, {
        AnalyticsParams.feature: feature,
        AnalyticsParams.reason: failure.reason,
      }),
    );
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
