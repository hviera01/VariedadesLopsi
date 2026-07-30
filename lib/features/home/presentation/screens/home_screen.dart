import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/constants/roles.dart';
import '../../../../core/providers/tabs_provider.dart';
import '../../../../core/models/tab_item.dart';
import '../../../../core/data/modulos_menu.dart';
import '../../../../core/utils/pantalla_builder.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../../providers/home_dashboard_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Mismo criterio que side_menu.dart (_puedeVer): el Administrador ve todo,
  // el Encargado solo lo que el admin le marcó en pantallasPermitidas, y el
  // resto de roles sigue la jerarquía fija de siempre. Sin esto, Inicio
  // mostraba (y dejaba abrir) módulos que un Encargado no tenía permitidos.
  bool _puedeVer(dynamic usuario, String rolUsuario, SubModulo s) {
    if (rolUsuario == Roles.administrador) return true;
    if (rolUsuario == Roles.encargado) {
      return usuario?.pantallasPermitidas[s.moduleKey] == true;
    }
    return Roles.cumpleNivel(rolUsuario, s.nivelMinimo);
  }

  void _abrirSubModulo(WidgetRef ref, SubModulo sub) {
    final esVentaNueva = sub.moduleKey == 'ventas_registrar';
    final id = esVentaNueva ? 'ventas_registrar_${DateTime.now().millisecondsSinceEpoch}' : sub.moduleKey;
    ref.read(tabsProvider.notifier).abrirTab(
      TabItem(
        id: id,
        titulo: sub.titulo,
        icono: sub.icono,
        contenido: construirPantalla(sub.moduleKey, sub.titulo, sub.icono, id),
      ),
    );
  }

  void _manejarTap(BuildContext context, WidgetRef ref, ModuloMenu modulo, String rolUsuario, dynamic usuario) {
    final disponibles = modulo.subModulos.where((s) => _puedeVer(usuario, rolUsuario, s)).toList();
    if (disponibles.isEmpty) return;
    if (disponibles.length == 1) {
      _abrirSubModulo(ref, disponibles.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 16),
                Text(modulo.titulo, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F1B3D))),
                const SizedBox(height: 8),
                ...disponibles.map((sub) {
                  return ListTile(
                    leading: Icon(sub.icono, color: modulo.color),
                    title: Text(sub.titulo, style: GoogleFonts.poppins(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _abrirSubModulo(ref, sub);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final usuario = authState.usuario;
    final rolUsuario = usuario?.rol ?? Roles.empleado;

    final modulosVisibles = obtenerModulos().where((m) {
      return m.subModulos.any((s) => _puedeVer(usuario, rolUsuario, s));
    }).toList();

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 640;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 16 : 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${usuario?.nombreCompleto ?? ''}',
                    style: GoogleFonts.poppins(fontSize: esMovil ? 20 : 24, fontWeight: FontWeight.w700, color: const Color(0xFF0F1B3D)),
                  ),
                  const SizedBox(height: 4),
                  Text('Seleccioná una opción para comenzar', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                  if (rolUsuario == Roles.administrador) ...[
                    const SizedBox(height: 20),
                    _resumenVentas(ref, esMovil),
                  ],
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modulosVisibles.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: esMovil ? 180 : 270,
                      mainAxisSpacing: esMovil ? 14 : 20,
                      crossAxisSpacing: esMovil ? 14 : 20,
                      childAspectRatio: esMovil ? 0.92 : 1.15,
                    ),
                    itemBuilder: (context, index) {
                      final modulo = modulosVisibles[index];
                      return _tarjetaModulo(context, ref, modulo, rolUsuario, usuario, esMovil);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _resumenVentas(WidgetRef ref, bool esMovil) {
    final ventasAsync = ref.watch(ventasDelMesProvider);
    return ventasAsync.when(
      loading: () => SizedBox(
        height: esMovil ? 74 : 84,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1B3D))),
      ),
      error: (e, st) => const SizedBox.shrink(),
      data: (ventas) {
        final resumen = calcularResumenVentas(ventas);
        return Wrap(
          spacing: esMovil ? 10 : 14,
          runSpacing: 10,
          children: [
            _tarjetaResumen('Hoy', resumen.hoy, Icons.today_outlined, const Color(0xFF16A34A), esMovil),
            _tarjetaResumen('Esta semana', resumen.semana, Icons.calendar_view_week_outlined, const Color(0xFF2563EB), esMovil),
            _tarjetaResumen('Este mes', resumen.mes, Icons.calendar_month_outlined, const Color(0xFF7C3AED), esMovil),
          ],
        );
      },
    );
  }

  Widget _tarjetaResumen(String etiqueta, double monto, IconData icono, Color color, bool esMovil) {
    return Container(
      width: esMovil ? double.infinity : 190,
      padding: EdgeInsets.symmetric(horizontal: esMovil ? 14 : 16, vertical: esMovil ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icono, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(etiqueta, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                Text(
                  formatearMoneda(monto),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaModulo(BuildContext context, WidgetRef ref, ModuloMenu modulo, String rolUsuario, dynamic usuario, bool esMovil) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _manejarTap(context, ref, modulo, rolUsuario, usuario),
        child: Container(
          padding: EdgeInsets.all(esMovil ? 14 : 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: esMovil ? 42 : 52,
                height: esMovil ? 42 : 52,
                decoration: BoxDecoration(color: modulo.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(modulo.icono, color: modulo.color, size: esMovil ? 20 : 26),
              ),
              SizedBox(height: esMovil ? 10 : 16),
              Text(
                modulo.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: esMovil ? 13 : 15.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 4),
              Text(
                '${modulo.subModulos.where((s) => _puedeVer(usuario, rolUsuario, s)).length} opciones',
                style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}