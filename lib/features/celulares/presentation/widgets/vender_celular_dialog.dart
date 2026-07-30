import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/celular_model.dart';
import '../../data/celular_garantia_export_service.dart';
import '../../providers/celulares_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../negocio/data/negocio_model.dart';
import '../../../negocio/providers/negocio_provider.dart';
import '../../../../core/widgets/pdf_preview_dialog.dart';

/// Wizard de 2 pasos para marcar un celular como VENDIDO: 1) fecha de venta
/// (default hoy), 2) nombre del cliente final (texto libre, no es un
/// buscador de Cliente real). Al confirmar, pregunta si se desea imprimir la
/// Nota de Garantía.
class VenderCelularDialog extends ConsumerStatefulWidget {
  final CelularModel celular;

  const VenderCelularDialog({super.key, required this.celular});

  @override
  ConsumerState<VenderCelularDialog> createState() => _VenderCelularDialogState();
}

class _VenderCelularDialogState extends ConsumerState<VenderCelularDialog> {
  int _paso = 0;
  DateTime _fechaVenta = DateTime.now();
  final _clienteController = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _clienteController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(context: context, initialDate: _fechaVenta, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (fecha == null) return;
    setState(() => _fechaVenta = fecha);
  }

  Future<void> _confirmarVenta() async {
    final nombreCliente = _clienteController.text.trim();
    if (nombreCliente.isEmpty) {
      setState(() => _error = 'El nombre del cliente es obligatorio');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? 'Sistema';
      await ref.read(celularRepositoryProvider).cambiarEstado(
            id: widget.celular.id,
            estadoAnterior: widget.celular.estado,
            estadoNuevo: EstadoCelular.vendido,
            usuario: usuario,
            nombreClienteFinal: nombreCliente,
            fechaVenta: _fechaVenta,
          );
      if (!mounted) return;
      Navigator.pop(context);
      await _preguntarImprimirGarantia(nombreCliente);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  Future<void> _preguntarImprimirGarantia(String nombreCliente) async {
    final context = this.context;
    final quiereImprimir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Imprimir garantía', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('¿Deseas imprimir la Nota de Garantía ahora?', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No', style: GoogleFonts.poppins())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sí', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (quiereImprimir != true) return;
    if (!context.mounted) return;

    // Se lee el negocio actual desde el provider (ya precargado en login).
    final negocioActual = ref.read(negocioStreamProvider).value ?? const NegocioModel();

    final celularActualizado = CelularModel(
      id: widget.celular.id,
      codigo: widget.celular.codigo,
      proveedor: widget.celular.proveedor,
      marca: widget.celular.marca,
      modelo: widget.celular.modelo,
      color: widget.celular.color,
      imei: widget.celular.imei,
      notas: widget.celular.notas,
      fechaCompra: widget.celular.fechaCompra,
      nombreClienteFinal: nombreCliente,
      fechaVenta: _fechaVenta,
      estado: EstadoCelular.vendido,
      usuarioReg: widget.celular.usuarioReg,
      fechaRegistro: widget.celular.fechaRegistro,
      fechaActualizacion: DateTime.now(),
    );

    final servicio = CelularGarantiaExportService();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Nota de Garantía · ${celularActualizado.codigo}',
        generarPdf: () => servicio.generarPdfGarantia(celularActualizado, negocioActual),
        nombreArchivo: 'garantia_${celularActualizado.codigo}.pdf',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final anchoDialog = esMovil ? tamano.width - 48 : 420.0;
    final formatoDia = DateFormat('dd/MM/yyyy');

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
                    'Marcar Vendido · ${widget.celular.codigo}',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _paso == 0 ? 'Paso 1 de 2: fecha de venta' : 'Paso 2 de 2: nombre del cliente final',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            if (_paso == 0) ...[
              InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 17, color: Color(0xFF6B7280)),
                      const SizedBox(width: 10),
                      Text('Fecha de venta: ${formatoDia.format(_fechaVenta)}', style: GoogleFonts.poppins(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _clienteController,
                autofocus: true,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre del cliente final',
                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFE8EAF0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
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
                if (_paso == 1)
                  TextButton(
                    onPressed: _guardando ? null : () => setState(() => _paso = 0),
                    child: Text('Atrás', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _guardando
                      ? null
                      : () {
                          if (_paso == 0) {
                            setState(() => _paso = 1);
                          } else {
                            _confirmarVenta();
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                      : Text(_paso == 0 ? 'Siguiente' : 'Confirmar Venta', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
