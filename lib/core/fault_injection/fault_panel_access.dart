/// Si el panel de fallos se puede abrir: build con `DEMO_TOOLS` y flag
/// `demo_fault_panel` encendido para el cliente. Lo usa el perfil para mostrar
/// el acceso; la ruta la protege además el guard.
class FaultPanelAccess {
  const FaultPanelAccess(this._isAllowed);

  final bool Function() _isAllowed;

  bool get isAllowed => _isAllowed();
}
