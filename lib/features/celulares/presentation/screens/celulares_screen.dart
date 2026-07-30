import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/celular_model.dart';
import '../../providers/celulares_provider.dart';
import '../../../../core/utils/texto_utils.dart';
import '../../data/celular_garantia_export_service.dart';
import '../../../negocio/data/negocio_model.dart';
import '../../../negocio/providers/negocio_provider.dart';
import '../../../../core/widgets/pdf_preview_dialog.dart';
import '../widgets/celular_form_dialog.dart';
import '../widgets/vender_celular_dialog.dart';
import '../widgets/cambiar_estado_celular_dialog.dart';
import '../widgets/historial_celular_dialog.dart';

class CelularesScreen extends ConsumerStatefulWidget {
  const CelularesScreen({super.key});

  @override
  ConsumerState<CelularesScreen> createState() => _CelularesScreenState();
}

class _CelularesScreenState extends ConsumerState<CelularesScreen> {
  final _busquedaController = TextEditingController();
  String? _filaSeleccionada;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _buscar() {
    ref.read(celularesBusquedaProvider.notifier).actualizar(_busquedaController.text.trim());
  }

  void _limpiarBusqueda() {
    _busquedaController.clear();
    ref.read(celularesBusquedaProvider.notifier).actualizar('');
  }

  void _abrirFormulario([CelularModel? celular]) {
    showDialog(context: context, builder: (context) => CelularFormDialog(celular: celular));
  }

  void _marcarVendido(CelularModel celular) {
    showDialog(context: context, builder: (context) => VenderCelularDialog(celular: celular));
  }

  void _verHistorial(CelularModel celular) {
    showDialog(context: context, builder: (context) => HistorialCelularDialog(celular: celular));
  }

  void _cambiarEstado(CelularModel celular, String estadoNuevo, String titulo) {
    showDialog(context: context, builder: (context) => CambiarEstadoCelularDialog(celular: celular, estadoNuevo: estadoNuevo, titulo: titulo));
  }

  Future<void> _reimprimirGarantia(CelularModel celular) async {
    final negocioActual = ref.read(negocioStreamProvider).value ?? const NegocioModel();
    final servicio = CelularGarantiaExportService();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => PdfPreviewDialog(
        titulo: 'Nota de Garantía · ${celular.codigo}',
        generarPdf: () => servicio.generarPdfGarantia(celular, negocioActual),
        nombreArchivo: 'garantia_${celular.codigo}.pdf',
      ),
    );
  }

  void _manejarAccion(String valor, CelularModel celular) {
    switch (valor) {
      case 'editar':
        _abrirFormulario(celular);
        break;
      case 'vender':
        _marcarVendido(celular);
        break;
      case 'reimprimir_garantia':
        _reimprimirGarantia(celular);
        break;
      case 'historial':
        _verHistorial(celular);
        break;
      case 'devuelto':
        _cambiarEstado(celular, EstadoCelular.devuelto, 'Marcar Devuelto');
        break;
      case 'mal_estado':
        _cambiarEstado(celular, EstadoCelular.malEstado, 'Marcar Mal Estado');
        break;
      case 'inactivo':
        _cambiarEstado(celular, EstadoCelular.inactivo, 'Marcar Inactivo');
        break;
      case 'disponible':
        _cambiarEstado(celular, EstadoCelular.disponible, 'Marcar Disponible');
        break;
    }
  }

  List<PopupMenuEntry<String>> _opcionesMenu(CelularModel celular) {
    final esDisponible = celular.estado == EstadoCelular.disponible;
    return [
      _opcionMenu(valor: 'editar', icono: Icons.edit_outlined, texto: 'Editar'),
      if (esDisponible) _opcionMenu(valor: 'vender', icono: Icons.sell_outlined, texto: 'Marcar Vendido'),
      if (celular.estado == EstadoCelular.vendido) _opcionMenu(valor: 'reimprimir_garantia', icono: Icons.print_outlined, texto: 'Reimprimir Garantía'),
      _opcionMenu(valor: 'historial', icono: Icons.history, texto: 'Ver Historial'),
      const PopupMenuDivider(),
      if (celular.estado != EstadoCelular.devuelto) _opcionMenu(valor: 'devuelto', icono: Icons.assignment_return_outlined, texto: 'Marcar Devuelto'),
      if (celular.estado != EstadoCelular.malEstado) _opcionMenu(valor: 'mal_estado', icono: Icons.report_problem_outlined, texto: 'Marcar Mal Estado'),
      if (celular.estado != EstadoCelular.inactivo) _opcionMenu(valor: 'inactivo', icono: Icons.block_outlined, texto: 'Marcar Inactivo'),
      if (!esDisponible) _opcionMenu(valor: 'disponible', icono: Icons.check_circle_outline, texto: 'Marcar Disponible'),
    ];
  }

  PopupMenuItem<String> _opcionMenu({required String valor, required IconData icono, required String texto}) {
    return PopupMenuItem<String>(
      value: valor,
      height: 42,
      child: Row(children: [Icon(icono, size: 18, color: const Color(0xFF4B4F58)), const SizedBox(width: 10), Text(texto, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF25272B)))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final celularesAsync = ref.watch(celularesStreamProvider);
    final busqueda = ref.watch(celularesBusquedaProvider);
    final filtroEstado = ref.watch(celularesFiltroEstadoProvider);

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 720;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 14 : 26),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Text(
                    'Celulares',
                    style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: esMovil ? constraints.maxWidth : 200, child: _selectorEstado(filtroEstado)),
                      SizedBox(width: esMovil ? constraints.maxWidth : 320, child: _buscador(busqueda)),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(celularesStreamProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text('Refrescar', style: GoogleFonts.poppins(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(color: Color(0xFFB6BCC7)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Nuevo Celular', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F1B3D),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 18)),
              ],
              body: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFAEB4C0), width: 1.3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 12))],
                ),
                child: celularesAsync.when(
                  data: (celulares) {
                    var lista = celulares;
                    if (busqueda.isNotEmpty) {
                      lista = lista.where((c) => coincideFuzzy(c.textoBusqueda, busqueda)).toList();
                    }
                    if (filtroEstado != null) {
                      lista = lista.where((c) => c.estado == filtroEstado).toList();
                    }

                    if (lista.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_iphone_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay celulares encontrados', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }

                    return esMovil ? _tarjetas(lista) : _tabla(lista);
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F1B3D))),
                  error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _selectorEstado(String? filtroEstado) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: filtroEstado,
          isExpanded: true,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos los estados')),
            ...EstadoCelular.todos.map((e) => DropdownMenuItem(value: e, child: Text(EstadoCelular.etiquetas[e] ?? e))),
          ],
          onChanged: (v) => ref.read(celularesFiltroEstadoProvider.notifier).actualizar(v),
        ),
      ),
    );
  }

  Widget _buscador(String busqueda) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _busquedaController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar por código, marca, modelo, IMEI o proveedor...',
                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          if (busqueda.isNotEmpty) IconButton(tooltip: 'Limpiar', icon: const Icon(Icons.close, size: 18), onPressed: _limpiarBusqueda),
          IconButton(tooltip: 'Buscar', icon: const Icon(Icons.arrow_forward, size: 18), onPressed: _buscar),
        ],
      ),
    );
  }

  Widget _tabla(List<CelularModel> lista) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mostrarProveedor = constraints.maxWidth >= 950;

        return ListView.builder(
          itemCount: lista.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFFECEEF3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                child: Row(
                  children: [
                    _celdaHeader('CÓDIGO', 2),
                    _celdaHeader('MARCA / MODELO', 3),
                    _celdaHeader('IMEI', 2),
                    if (mostrarProveedor) _celdaHeader('PROVEEDOR', 2),
                    _celdaHeader('ESTADO', 2),
                    const SizedBox(width: 56),
                  ],
                ),
              );
            }
            final celular = lista[index - 1];
            final seleccionada = _filaSeleccionada == celular.id;
            return Column(
              children: [
                if (index > 1) Divider(height: 1, color: Colors.grey.shade200),
                InkWell(
                  onTap: () => setState(() => _filaSeleccionada = seleccionada ? null : celular.id),
                  child: Container(
                    color: seleccionada ? const Color(0xFFFBEAEA) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _celda(2, celular.codigo, peso: FontWeight.w600),
                        _celda(3, '${celular.marca} ${celular.modelo}'.trim()),
                        _celda(2, celular.imei.isEmpty ? '-' : celular.imei, gris: true),
                        if (mostrarProveedor) _celda(2, celular.proveedor.isEmpty ? '-' : celular.proveedor, gris: true),
                        Expanded(flex: 2, child: _chipEstado(celular.estado)),
                        SizedBox(width: 56, child: _celdaAcciones(celular)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _celdaHeader(String texto, int flex) {
    return Expanded(
      flex: flex,
      child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF666A72), letterSpacing: 0.35)),
    );
  }

  Widget _celda(int flex, String texto, {bool gris = false, FontWeight peso = FontWeight.w400}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          texto,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: peso, color: gris ? Colors.grey.shade600 : const Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case EstadoCelular.disponible:
        return const Color(0xFF16A34A);
      case EstadoCelular.vendido:
        return const Color(0xFF3B82F6);
      case EstadoCelular.malEstado:
        return const Color(0xFFF59E0B);
      case EstadoCelular.devuelto:
        return const Color(0xFFEC4899);
      case EstadoCelular.inactivo:
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _chipEstado(String estado) {
    final color = _colorEstado(estado);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(EstadoCelular.etiquetas[estado] ?? estado, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _celdaAcciones(CelularModel celular) {
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      padding: EdgeInsets.zero,
      icon: Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFDFE1E6))), child: const Icon(Icons.more_vert, size: 19, color: Color(0xFF454950))),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      position: PopupMenuPosition.under,
      onSelected: (valor) => _manejarAccion(valor, celular),
      itemBuilder: (context) => _opcionesMenu(celular),
    );
  }

  Widget _tarjetas(List<CelularModel> lista) {
    final formatoDia = DateFormat('dd/MM/yyyy');
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: lista.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final celular = lista[index];
        final seleccionada = _filaSeleccionada == celular.id;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _filaSeleccionada = seleccionada ? null : celular.id),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: seleccionada ? const Color(0xFFFBEAEA) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: seleccionada ? const Color(0xFF0F1B3D) : const Color(0xFFC7CBD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${celular.marca} ${celular.modelo}'.trim().isEmpty ? celular.codigo : '${celular.marca} ${celular.modelo}',
                        style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      ),
                    ),
                    _celdaAcciones(celular),
                  ],
                ),
                const SizedBox(height: 6),
                Text(celular.codigo, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade500)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (celular.imei.isNotEmpty) _chipInfo('IMEI', celular.imei),
                    if (celular.color.isNotEmpty) _chipInfo('Color', celular.color),
                    if (celular.proveedor.isNotEmpty) _chipInfo('Proveedor', celular.proveedor),
                    if (celular.fechaCompra != null) _chipInfo('Compra', formatoDia.format(celular.fechaCompra!)),
                    _chipEstado(celular.estado),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipInfo(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE8EAF0), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $valor', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF3F434A))),
    );
  }
}
