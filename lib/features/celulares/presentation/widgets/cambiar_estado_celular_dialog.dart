import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/celular_model.dart';
import '../../providers/celulares_provider.dart';
import '../../../auth/providers/auth_provider.dart';

/// Diálogo simple de confirmación para los demás cambios de estado
/// (Devuelto/MalEstado/Inactivo/Disponible): pide una observación opcional y
/// graba el historial con esa observación. No requiere wizard ni impresión.
class CambiarEstadoCelularDialog extends ConsumerStatefulWidget {
  final CelularModel celular;
  final String estadoNuevo;
  final String titulo;

  const CambiarEstadoCelularDialog({super.key, required this.celular, required this.estadoNuevo, required this.titulo});

  @override
  ConsumerState<CambiarEstadoCelularDialog> createState() => _CambiarEstadoCelularDialogState();
}

class _CambiarEstadoCelularDialogState extends ConsumerState<CambiarEstadoCelularDialog> {
  final _observacionController = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? 'Sistema';
      await ref.read(celularRepositoryProvider).cambiarEstado(
            id: widget.celular.id,
            estadoAnterior: widget.celular.estado,
            estadoNuevo: widget.estadoNuevo,
            usuario: usuario,
            observacion: _observacionController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final anchoDialog = esMovil ? tamano.width - 48 : 420.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: anchoDialog,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.titulo} · ${widget.celular.codigo}',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '¿Seguro que querés cambiar el estado de este celular a "${EstadoCelular.etiquetas[widget.estadoNuevo] ?? widget.estadoNuevo}"?',
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observacionController,
              autofocus: true,
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Observación (opcional)',
                labelStyle: GoogleFonts.poppins(fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFE8EAF0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _guardando ? null : _confirmar,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                      : Text('Confirmar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
