import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/celular_model.dart';
import '../../providers/celulares_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class CelularFormDialog extends ConsumerStatefulWidget {
  final CelularModel? celular;

  const CelularFormDialog({super.key, this.celular});

  @override
  ConsumerState<CelularFormDialog> createState() => _CelularFormDialogState();
}

class _CelularFormDialogState extends ConsumerState<CelularFormDialog> {
  final _proveedorController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _imeiController = TextEditingController();
  final _notasController = TextEditingController();
  DateTime _fechaCompra = DateTime.now();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.celular;
    if (c != null) {
      _proveedorController.text = c.proveedor;
      _marcaController.text = c.marca;
      _modeloController.text = c.modelo;
      _colorController.text = c.color;
      _imeiController.text = c.imei;
      _notasController.text = c.notas;
      _fechaCompra = c.fechaCompra ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _proveedorController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _colorController.dispose();
    _imeiController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(context: context, initialDate: _fechaCompra, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (fecha == null) return;
    setState(() => _fechaCompra = fecha);
  }

  Future<void> _guardar() async {
    final proveedor = _proveedorController.text.trim();
    final marca = _marcaController.text.trim();
    final modelo = _modeloController.text.trim();
    final imei = _imeiController.text.trim();
    if (proveedor.isEmpty || marca.isEmpty || modelo.isEmpty || imei.isEmpty) {
      setState(() => _error = 'Proveedor, Marca, Modelo e IMEI son obligatorios');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(celularRepositoryProvider);
      final usuario = ref.read(authProvider).usuario?.nombreCompleto ?? 'Sistema';
      if (widget.celular == null) {
        await repo.crear(
          proveedor: proveedor,
          marca: marca,
          modelo: modelo,
          color: _colorController.text.trim(),
          imei: imei,
          notas: _notasController.text.trim(),
          fechaCompra: _fechaCompra,
          usuario: usuario,
        );
      } else {
        await repo.actualizar(
          id: widget.celular!.id,
          proveedor: proveedor,
          marca: marca,
          modelo: modelo,
          color: _colorController.text.trim(),
          imei: imei,
          notas: _notasController.text.trim(),
          fechaCompra: _fechaCompra,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _guardando = false;
      });
    }
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFE8EAF0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.celular != null;
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    final anchoDialog = esMovil ? tamano.width - 48 : 460.0;
    final formatoDia = DateFormat('dd/MM/yyyy');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: anchoDialog,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF0F1B3D).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.phone_iphone_outlined, color: Color(0xFF0F1B3D)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      editando ? 'Editar Celular' : 'Nuevo Celular',
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _proveedorController,
                      autofocus: true,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _decoracion('Proveedor'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _marcaController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: _decoracion('Marca'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _modeloController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: _decoracion('Modelo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _colorController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: _decoracion('Color (opcional)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _imeiController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: _decoracion('IMEI'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                            Text('Fecha de compra: ${formatoDia.format(_fechaCompra)}', style: GoogleFonts.poppins(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notasController,
                      maxLines: 3,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _decoracion('Notas (opcional)'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F1B3D),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : Text('Guardar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
