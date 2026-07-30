import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reportes/providers/reportes_provider.dart';
import '../../reportes/data/reporte_venta_model.dart';

/// Ventas reales (sin anular, sin cotizaciones) del mes en curso hasta
/// ahora — un solo query liviano (solo encabezados, sin detalle de líneas)
/// que alcanza para calcular los resúmenes de hoy/semana/mes del panel de
/// Inicio sin repetir la consulta tres veces.
final ventasDelMesProvider = FutureProvider.autoDispose<List<ReporteVentaModel>>((ref) async {
  final ahora = DateTime.now();
  final inicioMes = DateTime(ahora.year, ahora.month, 1);
  final repo = ref.watch(reporteRepositoryProvider);
  final ventas = await repo.obtenerReporteVentas(inicioMes, ahora);
  return ventas.where((v) => v.estado != 'Anulada' && v.tipoDocumento != 'Cotizacion' && v.tipoDocumento != 'Canje').toList();
});

class ResumenVentas {
  final double hoy;
  final double semana;
  final double mes;

  const ResumenVentas({required this.hoy, required this.semana, required this.mes});
}

ResumenVentas calcularResumenVentas(List<ReporteVentaModel> ventas) {
  final ahora = DateTime.now();
  final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
  // Semana de lunes a domingo.
  final inicioSemana = inicioHoy.subtract(Duration(days: inicioHoy.weekday - 1));

  var hoy = 0.0, semana = 0.0, mes = 0.0;
  for (final v in ventas) {
    final fecha = v.fechaRegistro;
    if (fecha == null) continue;
    mes += v.totalAPagar;
    if (!fecha.isBefore(inicioSemana)) semana += v.totalAPagar;
    if (!fecha.isBefore(inicioHoy)) hoy += v.totalAPagar;
  }
  return ResumenVentas(hoy: hoy, semana: semana, mes: mes);
}
