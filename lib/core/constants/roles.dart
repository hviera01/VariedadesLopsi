class Roles {
  static const administrador = 'Administrador';
  static const semiAdministrador = 'Semi Administrador';
  static const empleado = 'Empleado';

  static const List<String> todos = [administrador, semiAdministrador, empleado];

  static int _nivel(String rol) {
    switch (rol) {
      case administrador:
        return 2;
      case semiAdministrador:
        return 1;
      default:
        return 0;
    }
  }

  /// true si [rolUsuario] tiene al menos el nivel de [rolMinimo] (Empleado <
  /// Semi Administrador < Administrador).
  static bool cumpleNivel(String rolUsuario, String rolMinimo) => _nivel(rolUsuario) >= _nivel(rolMinimo);
}
