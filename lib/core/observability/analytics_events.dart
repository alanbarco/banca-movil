/// Catálogo de eventos de `contracts/analytics-events.md`.
abstract final class AnalyticsEvents {
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingAbandoned = 'onboarding_abandoned';
  static const onboardingCompleted = 'onboarding_completed';
  static const loginSuccess = 'login_success';
  static const loginFailure = 'login_failure';
  static const sessionTimeout = 'session_timeout';
  static const dataLoadError = 'data_load_error';
  static const staleDataShown = 'stale_data_shown';
  static const sduiSectionSkipped = 'sdui_section_skipped';
  static const featureFlagEvaluated = 'feature_flag_evaluated';
  static const fxServiceFailure = 'fx_service_failure';
  static const pushOpened = 'push_opened';
  static const connectivityChanged = 'connectivity_changed';
}

/// Nombres de parámetros permitidos en los eventos.
abstract final class AnalyticsParams {
  static const step = 'step';
  static const lastStep = 'last_step';
  static const segment = 'segment';
  static const reason = 'reason';
  static const feature = 'feature';
  static const sectionType = 'section_type';
  static const flag = 'flag';
  static const enabled = 'enabled';
  static const type = 'type';
  static const online = 'online';
}

/// User properties (sin PII).
abstract final class AnalyticsUserProperties {
  static const segment = 'segment';
}
