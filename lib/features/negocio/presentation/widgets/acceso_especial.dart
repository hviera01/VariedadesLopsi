import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/negocio_repository.dart';
import '../../providers/negocio_provider.dart';
import '../../../../core/constants/roles.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../usuarios/data/usuario_model.dart';
import '../../../usuarios/providers/usuarios_provider.dart';

/// Resultado de [verificarAccesoEspecial]: si quedó autorizado y, cuando
/// aplica, qué usuario del sistema asumió la responsabilidad de autorizar
/// (igual que el "usuario responsable" del sistema viejo — no es
/// necesariamente quien está logueado, es a quien el cajero le pidió el
/// visto bueno).
class ResultadoAccesoEspecial {
  final bool autorizado;
  final String usuarioAutoriza;

  const ResultadoAccesoEspecial({required this.autorizado, this.usuarioAutoriza = ''});
}

/// Si el permiso [permisoKey] está activado y hay una clave especial configurada,
/// pide la clave y quién autoriza antes de continuar. Si no está activado (o no hay
/// clave configurada), retorna autorizado de inmediato sin mostrar nada, con el
/// usuario logueado como responsable implícito. El Administrador nunca la pide: es
/// el único rol que puede hacer todo sin restricciones.
Future<ResultadoAccesoEspecial> verificarAccesoEspecial(BuildContext context, WidgetRef ref, String permisoKey) async {
  final usuarioLogueado = ref.read(authProvider).usuario;
  if (usuarioLogueado?.rol == Roles.administrador) {
    return ResultadoAccesoEspecial(autorizado: true, usuarioAutoriza: usuarioLogueado?.nombreCompleto ?? '');
  }
  final negocio = await ref.read(negocioRepositoryProvider).obtenerNegocioActual();
  if (!negocio.tieneClaveEspecial || !negocio.tienePermiso(permisoKey)) {
    return ResultadoAccesoEspecial(autorizado: true, usuarioAutoriza: usuarioLogueado?.nombreCompleto ?? '');
  }
  if (!context.mounted) return const ResultadoAccesoEspecial(autorizado: false);
  final repo = ref.read(negocioRepositoryProvider);
  final usuarios = await ref.read(usuariosStreamProvider.future);
  if (!context.mounted) return const ResultadoAccesoEspecial(autorizado: false);
  final resultado = await showDialog<ResultadoAccesoEspecial>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ClaveEspecialDialog(
      hashEsperado: negocio.claveEspecialHash,
      repo: repo,
      usuarios: usuarios.where((u) => u.estado).toList(),
      usuarioLogueadoId: usuarioLogueado?.id,
    ),
  );
  return resultado ?? const ResultadoAccesoEspecial(autorizado: false);
}

class _ClaveEspecialDialog extends StatefulWidget {
  final String hashEsperado;
  final NegocioRepository repo;
  final List<UsuarioModel> usuarios;
  final String? usuarioLogueadoId;

  const _ClaveEspecialDialog({required this.hashEsperado, required this.repo, required this.usuarios, this.usuarioLogueadoId});

  @override
  State<_ClaveEspecialDialog> createState() => _ClaveEspecialDialogState();
}

class _ClaveEspecialDialogState extends State<_ClaveEspecialDialog> {
  final _controller = TextEditingController();
  String? _error;
  String? _usuarioSeleccionadoId;

  @override
  void initState() {
    super.initState();
    // Preselecciona al usuario que está logueado en la caja, si está en la
    // lista de usuarios activos — el cajero solo tiene que cambiarlo si
    // realmente es OTRA persona quien está autorizando.
    if (widget.usuarios.any((u) => u.id == widget.usuarioLogueadoId)) {
      _usuarioSeleccionadoId = widget.usuarioLogueadoId;
    } else if (widget.usuarios.isNotEmpty) {
      _usuarioSeleccionadoId = widget.usuarios.first.id;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_usuarioSeleccionadoId == null) {
      setState(() => _error = 'Seleccioná quién autoriza');
      return;
    }
    final clave = _controller.text;
    if (clave.isEmpty) {
      setState(() => _error = 'Ingresá la clave');
      return;
    }
    final valido = widget.repo.hashClave(clave) == widget.hashEsperado;
    if (!valido) {
      setState(() {
        _error = 'Clave incorrecta';
        _controller.clear();
      });
      return;
    }
    final nombreResponsable = widget.usuarios.firstWhere((u) => u.id == _usuarioSeleccionadoId).nombreCompleto;
    Navigator.pop(context, ResultadoAccesoEspecial(autorizado: true, usuarioAutoriza: nombreResponsable));
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final esMovil = tamano.width < 480;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: esMovil ? tamano.width - 48 : 380,
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
                  decoration: BoxDecoration(color: const Color(0xFFFBEAEA), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.lock_outline, color: Color(0xFF0F1B3D), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Acceso especial requerido', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Esta acción está protegida. Seleccioná quién autoriza e ingresá la clave especial para continuar.', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _usuarioSeleccionadoId,
              isExpanded: true,
              style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: '¿Quién autoriza?',
                filled: true,
                fillColor: const Color(0xFFE8EAF0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: widget.usuarios.map((u) => DropdownMenuItem(value: u.id, child: Text(u.nombreCompleto, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _usuarioSeleccionadoId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              onSubmitted: (_) => _confirmar(),
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Clave especial',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
                errorText: _error,
                filled: true,
                fillColor: const Color(0xFFE8EAF0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1A1A), side: const BorderSide(color: Color(0xFFB6BCC7)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Cancelar', style: GoogleFonts.poppins(fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirmar,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F1B3D), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Confirmar', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
