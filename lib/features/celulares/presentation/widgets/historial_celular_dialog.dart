import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/celular_model.dart';
import '../../data/historial_celular_model.dart';
import '../../providers/celulares_provider.dart';

/// Modal con el historial de estados de un celular puntual, más reciente
/// primero (mismo patrón visual que HistorialStockDialog de Productos).
class HistorialCelularDialog extends ConsumerWidget {
  final CelularModel celular;

  const HistorialCelularDialog({super.key, required this.celular});

  String _etiqueta(String estado) => EstadoCelular.etiquetas[estado] ?? estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialCelularProvider(celular.id));
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    final formatoDia = DateFormat('dd/MM/yyyy');
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 640;
    final anchoDialog = esMovil ? tamano.width - 24 : 720.0;
    final altoDialog = tamano.height < 640 ? tamano.height - 40 : 580.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: anchoDialog,
        height: altoDialog,
        padding: EdgeInsets.all(esMovil ? 16 : 22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Historial · ${celular.codigo}', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: historialAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F1B3D))),
                error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                data: (registros) {
                  if (registros.isEmpty) {
                    return Center(child: Text('Sin movimientos todavía', style: GoogleFonts.poppins(color: Colors.grey.shade500)));
                  }
                  return ListView.separated(
                    itemCount: registros.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _tarjetaHistorial(registros[index], formatoFecha, formatoDia),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaHistorial(HistorialCelularModel r, DateFormat formatoFecha, DateFormat formatoDia) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFC7CBD3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${_etiqueta(r.estadoAnterior)} → ${_etiqueta(r.estadoNuevo)}',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Text(r.fecha != null ? formatoFecha.format(r.fecha!) : '-', style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade500)),
            ],
          ),
          if (r.nombreClienteFinal.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Cliente: ${r.nombreClienteFinal}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
          ],
          if (r.fechaVenta != null) ...[
            const SizedBox(height: 4),
            Text('Fecha de venta: ${formatoDia.format(r.fechaVenta!)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
          ],
          if (r.observacion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.observacion, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
          ],
          const SizedBox(height: 6),
          Text(r.usuario, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
