import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/cliente_model.dart';
import '../../providers/clientes_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../negocio/data/negocio_model.dart';
import '../../../negocio/presentation/widgets/acceso_especial.dart';

/// Equivalente a MdPuntos del sistema viejo: saldo actual, historial de
/// movimientos (ledger, ver MovimientoPuntosModel) y ajuste manual protegido
/// por la clave especial "Ajustar puntos de un cliente a mano".
class PuntosClienteDialog extends ConsumerStatefulWidget {
  final ClienteModel cliente;

  const PuntosClienteDialog({super.key, required this.cliente});

  @override
  ConsumerState<PuntosClienteDialog> createState() => _PuntosClienteDialogState();
}

class _PuntosClienteDialogState extends ConsumerState<PuntosClienteDialog> {
  final _ajusteController = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _ajusteController.dispose();
    super.dispose();
  }

  Future<void> _aplicarAjuste() async {
    final valor = double.tryParse(_ajusteController.text.replaceAll(',', '').trim());
    if (valor == null || valor == 0) {
      setState(() => _error = 'Ingresá una cantidad de puntos distinta de cero (negativo para restar)');
      return;
    }
    final resultado = await verificarAccesoEspecial(context, ref, PermisosEspeciales.actualizarPuntos);
    if (!mounted) return;
    if (!resultado.autorizado) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final usuario = ref.read(authProvider).usuario;
      await ref.read(clienteRepositoryProvider).registrarMovimientoPuntos(
            idCliente: widget.cliente.id,
            puntos: valor,
            tipo: 'AjusteManual',
            descripcion: 'Actualización manual: ${valor > 0 ? '+' : ''}${valor.toStringAsFixed(0)}',
            usuario: usuario?.nombreCompleto ?? 'Sistema',
            usuarioAutoriza: resultado.usuarioAutoriza,
          );
      if (mounted) {
        _ajusteController.clear();
        setState(() => _guardando = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final movimientosAsync = ref.watch(movimientosPuntosProvider(widget.cliente.id));
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: esMovil ? tamano.width - 48 : 460,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.stars_rounded, color: Color(0xFF0F1B3D), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Puntos de fidelización', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                      Text(widget.cliente.nombreCompleto, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFF0F1B3D), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text('SALDO ACTUAL', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(widget.cliente.saldoPuntos.toStringAsFixed(0), style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ajusteController,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ej: 50 o -20',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFE8EAF0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _guardando ? null : _aplicarAjuste,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _guardando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Actualizar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700)),
            ],
            const SizedBox(height: 18),
            Text('Historial', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Flexible(
              child: movimientosAsync.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('No se pudo cargar el historial', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.red.shade700))),
                data: (movimientos) {
                  if (movimientos.isEmpty) {
                    return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Todavía no hay movimientos de puntos.', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade500)));
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: movimientos.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final m = movimientos[i];
                      final positivo = m.puntos >= 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.descripcion.isEmpty ? m.tipo : m.descripcion, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  Text(
                                    m.fecha != null ? formatoFecha.format(m.fecha!) : '-',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                  if (m.usuarioAutoriza.isNotEmpty)
                                    Text('Autorizó: ${m.usuarioAutoriza}', style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text(
                              '${positivo ? '+' : ''}${m.puntos.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: positivo ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
