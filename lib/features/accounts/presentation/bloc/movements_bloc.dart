import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/connectivity_status.dart';
import '../../../../core/data/data_snapshot.dart';
import '../../../../core/data/load_status.dart';
import '../../../../core/data/stale_data_gate.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/observability/analytics_events.dart';
import '../../../../core/observability/observability_service.dart';
import '../../../../core/session/current_user_profile.dart';
import '../../domain/entities/movement.dart';
import '../../domain/usecases/fetch_more_movements.dart';
import '../../domain/usecases/watch_recent_movements.dart';

sealed class MovementsEvent extends Equatable {
  const MovementsEvent();

  @override
  List<Object?> get props => const [];
}

/// Empieza a escuchar la primera página en vivo.
final class MovementsStarted extends MovementsEvent {
  const MovementsStarted();
}

final class MovementsRetried extends MovementsEvent {
  const MovementsRetried();
}

/// Pide la página siguiente (scroll al final o botón "Ver más").
final class MovementsLoadMoreRequested extends MovementsEvent {
  const MovementsLoadMoreRequested();
}

final class _LiveUpdated extends MovementsEvent {
  const _LiveUpdated(this.result);

  final Result<DataSnapshot<MovementPage>> result;

  @override
  List<Object?> get props => [result];
}

/// Cambió la conectividad o venció la espera de confirmación del servidor.
final class _StalenessChanged extends MovementsEvent {
  const _StalenessChanged();
}

class MovementsState extends Equatable {
  const MovementsState({
    this.status = LoadStatus.initial,
    this.live = const [],
    this.older = const [],
    this.liveHasMore = false,
    this.olderHasMore,
    this.loadingMore = false,
    this.loadMoreFailure,
    this.failure,
    this.lastSyncedAt,
  });

  final LoadStatus status;

  /// Primera página, actualizada en tiempo real.
  final List<Movement> live;

  /// Páginas pedidas con "ver más" (no se actualizan en vivo).
  final List<Movement> older;
  final bool liveHasMore;

  /// `null` hasta pedir la primera página adicional.
  final bool? olderHasMore;
  final bool loadingMore;
  final Failure? loadMoreFailure;
  final Failure? failure;
  final DateTime? lastSyncedAt;

  List<Movement> get items => [...live, ...older];

  bool get hasMore => olderHasMore ?? liveHasMore;

  bool get hasData =>
      status == LoadStatus.success || status == LoadStatus.stale;

  MovementsState copyWith({
    LoadStatus? status,
    List<Movement>? live,
    List<Movement>? older,
    bool? liveHasMore,
    bool? olderHasMore,
    bool? loadingMore,
    Failure? Function()? loadMoreFailure,
    Failure? Function()? failure,
    DateTime? Function()? lastSyncedAt,
  }) {
    return MovementsState(
      status: status ?? this.status,
      live: live ?? this.live,
      older: older ?? this.older,
      liveHasMore: liveHasMore ?? this.liveHasMore,
      olderHasMore: olderHasMore ?? this.olderHasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailure: loadMoreFailure != null
          ? loadMoreFailure()
          : this.loadMoreFailure,
      failure: failure != null ? failure() : this.failure,
      lastSyncedAt: lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    live,
    older,
    liveHasMore,
    olderHasMore,
    loadingMore,
    loadMoreFailure,
    failure,
    lastSyncedAt,
  ];
}

/// Movimientos de una cuenta: primera página en vivo + paginación (FR-011,
/// FR-012).
class MovementsBloc extends Bloc<MovementsEvent, MovementsState> {
  MovementsBloc({
    required this.accountId,
    required WatchRecentMovements watchRecentMovements,
    required FetchMoreMovements fetchMoreMovements,
    required CurrentUserProfile currentUser,
    required ConnectivityStatus connectivity,
    required ObservabilityService observability,
    Duration staleGrace = StaleDataGate.defaultGrace,
  }) : _watchRecent = watchRecentMovements,
       _fetchMore = fetchMoreMovements,
       _currentUser = currentUser,
       _observability = observability,
       super(const MovementsState()) {
    _gate = StaleDataGate(
      connectivity: connectivity,
      onChange: () {
        if (!isClosed) add(const _StalenessChanged());
      },
      grace: staleGrace,
    );
    on<MovementsStarted>((_, emit) => _subscribe(emit));
    on<MovementsRetried>((_, emit) => _subscribe(emit));
    on<_LiveUpdated>(_onLiveUpdated);
    on<_StalenessChanged>(_onStalenessChanged);
    on<MovementsLoadMoreRequested>(_onLoadMore);
  }

  static const feature = 'movements';

  final String accountId;
  final WatchRecentMovements _watchRecent;
  final FetchMoreMovements _fetchMore;
  final CurrentUserProfile _currentUser;
  final ObservabilityService _observability;
  late final StaleDataGate _gate;
  StreamSubscription<Result<DataSnapshot<MovementPage>>>? _subscription;

  void _subscribe(Emitter<MovementsState> emit) {
    unawaited(_subscription?.cancel());
    _gate.reset();
    final uid = _currentUser.current?.uid;
    if (uid == null) {
      _fail(emit, const Failure.unauthorized());
      return;
    }
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    _subscription = _watchRecent(
      uid,
      accountId,
    ).listen((result) => add(_LiveUpdated(result)));
  }

  void _onLiveUpdated(_LiveUpdated event, Emitter<MovementsState> emit) {
    event.result.fold((failure) => _fail(emit, failure), (snapshot) {
      final page = snapshot.data;
      final older = _keepDropped(page.items);
      final isEmpty = page.items.isEmpty && older.isEmpty;
      _gate.track(fromCache: snapshot.isStale);
      final LoadStatus status;
      if (isEmpty) {
        // Caché vacía: se espera al servidor en lugar de decir "sin
        // movimientos".
        if (snapshot.isStale) return;
        status = LoadStatus.empty;
      } else {
        status = _dataStatus;
      }
      _logIfBecomingStale(status);
      emit(
        state.copyWith(
          status: status,
          live: page.items,
          older: older,
          liveHasMore: page.hasMore,
          failure: () => null,
          lastSyncedAt: () => snapshot.lastSyncedAt,
        ),
      );
    });
  }

  /// Los datos de caché se muestran como `success` hasta que [StaleDataGate]
  /// decide mostrar el aviso de datos desactualizados.
  LoadStatus get _dataStatus =>
      _gate.showStale ? LoadStatus.stale : LoadStatus.success;

  void _onStalenessChanged(
    _StalenessChanged event,
    Emitter<MovementsState> emit,
  ) {
    if (!state.hasData) return;
    final status = _dataStatus;
    if (status == state.status) return;
    _logIfBecomingStale(status);
    emit(state.copyWith(status: status));
  }

  void _logIfBecomingStale(LoadStatus next) {
    if (next != LoadStatus.stale || state.status == LoadStatus.stale) return;
    unawaited(
      _observability.logEvent(AnalyticsEvents.staleDataShown, {
        AnalyticsParams.feature: feature,
      }),
    );
  }

  /// Con páginas extra cargadas, un movimiento nuevo empuja el último de la
  /// primera página fuera de ella: se conserva al inicio de [older] para que
  /// la lista no tenga huecos.
  List<Movement> _keepDropped(List<Movement> newLive) {
    if (state.olderHasMore == null) return state.older;
    final kept = {
      for (final m in newLive) m.id,
      for (final m in state.older) m.id,
    };
    final dropped = [
      for (final m in state.live)
        if (!kept.contains(m.id)) m,
    ];
    return [...dropped, ...state.older];
  }

  Future<void> _onLoadMore(
    MovementsLoadMoreRequested event,
    Emitter<MovementsState> emit,
  ) async {
    final uid = _currentUser.current?.uid;
    final items = state.items;
    if (uid == null ||
        state.loadingMore ||
        !state.hasMore ||
        !state.hasData ||
        items.isEmpty) {
      return;
    }
    emit(state.copyWith(loadingMore: true, loadMoreFailure: () => null));
    final result = await _fetchMore(uid, accountId, after: items.last);
    result.fold(
      (failure) {
        _logLoadError(failure);
        emit(
          state.copyWith(loadingMore: false, loadMoreFailure: () => failure),
        );
      },
      (snapshot) {
        final known = {for (final m in state.items) m.id};
        emit(
          state.copyWith(
            older: [
              ...state.older,
              for (final m in snapshot.data.items)
                if (!known.contains(m.id)) m,
            ],
            olderHasMore: snapshot.data.hasMore,
            loadingMore: false,
          ),
        );
      },
    );
  }

  void _fail(Emitter<MovementsState> emit, Failure failure) {
    _gate.reset();
    _logLoadError(failure);
    emit(state.copyWith(status: LoadStatus.failure, failure: () => failure));
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
    await _subscription?.cancel();
    await _gate.dispose();
    return super.close();
  }
}
