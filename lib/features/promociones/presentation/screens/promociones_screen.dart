import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/promocion_model.dart';
import '../../data/promocion_evaluador.dart';
import '../../providers/promociones_provider.dart';
import '../widgets/promocion_form_dialog.dart';

class PromocionesScreen extends ConsumerStatefulWidget {
  const PromocionesScreen({super.key});

  @override
  ConsumerState<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends ConsumerState<PromocionesScreen> {
  String _busqueda = '';
  // null = todas, true = solo vigentes, false = solo vencidas/inactivas.
  bool? _filtroVigente;

  void _abrirFormulario(BuildContext context, [PromocionModel? promocion]) {
    showDialog(context: context, builder: (context) => PromocionFormDialog(promocion: promocion));
  }

  Future<void> _alternarActiva(PromocionModel promo) async {
    await ref.read(promocionRepositoryProvider).establecerActiva(promo.id, !promo.activa);
  }

  @override
  Widget build(BuildContext context) {
    final promocionesAsync = ref.watch(promocionesStreamProvider);
    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 640;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 16 : 28),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Text('Descuentos y Promociones', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                SliverToBoxAdapter(
                  child: Text(
                    'Descuentos por porcentaje o precio fijo, combos por cantidad y regalos — se ofrecen solos al armar una venta.',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade500),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: esMovil
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_buscador(), const SizedBox(height: 12), _botonNuevo(context)],
                        )
                      : Row(
                          children: [
                            Expanded(child: _buscador()),
                            const SizedBox(width: 12),
                            _botonNuevo(context),
                          ],
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _filtrosVigencia()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
              body: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB6BCC7), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: promocionesAsync.when(
                  data: (promociones) {
                    final filtradas = promociones.where((p) {
                      final coincideTexto = _busqueda.isEmpty || p.nombre.toLowerCase().contains(_busqueda.toLowerCase());
                      final coincideFiltro = _filtroVigente == null || p.vigente() == _filtroVigente;
                      return coincideTexto && coincideFiltro;
                    }).toList();

                    if (filtradas.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sell_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay promociones', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: filtradas.length,
                      separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, i) => _filaPromocion(filtradas[i], esMovil),
                    );
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

  Widget _filaPromocion(PromocionModel promo, bool esMovil) {
    final vigente = promo.vigente();
    final formatoFecha = DateFormat('dd/MM/yyyy');
    final rangoFecha = '${formatoFecha.format(promo.fechaInicio)} — ${promo.esIndefinida ? 'Indefinido' : formatoFecha.format(promo.fechaFin!)}';
    final alcance = promo.condicionRestringida.isEmpty ? 'Todos los métodos de pago' : 'Solo ${promo.condicionRestringida == 'Contado' ? 'Contado' : 'Crédito'}';
    return InkWell(
      onTap: () => _abrirFormulario(context, promo),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: esMovil ? 14 : 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(promo.nombre, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                  const SizedBox(height: 3),
                  Text(descripcionCortaPromocion(promo), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 3),
                  Text(
                    '${promo.idsProductos.length} producto(s) · $rangoFecha · $alcance',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: vigente ? const Color(0xFFE8F8EE) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: Text(
                !promo.activa ? 'Desactivada' : (vigente ? 'Vigente' : (DateTime.now().isBefore(promo.fechaInicio) ? 'Próxima' : 'Vencida')),
                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: vigente ? const Color(0xFF16A34A) : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 6),
            Switch(value: promo.activa, activeThumbColor: const Color(0xFF16A34A), onChanged: (_) => _alternarActiva(promo)),
          ],
        ),
      ),
    );
  }

  Widget _buscador() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 46,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB6BCC7))),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(hintText: 'Buscar por nombre...', hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400), border: InputBorder.none, isDense: true),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtrosVigencia() {
    Widget chip(String texto, bool? valor) {
      final activo = _filtroVigente == valor;
      return ChoiceChip(
        label: Text(texto, style: GoogleFonts.poppins(fontSize: 12.5)),
        selected: activo,
        onSelected: (_) => setState(() => _filtroVigente = valor),
        selectedColor: const Color(0xFF0F1B3D),
        labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: activo ? Colors.white : const Color(0xFF1A1A1A)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFB6BCC7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: [chip('Todas', null), chip('Vigentes', true), chip('No vigentes', false)]);
  }

  Widget _botonNuevo(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _abrirFormulario(context),
      icon: const Icon(Icons.add, size: 18),
      label: Text('Nueva Promoción', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
