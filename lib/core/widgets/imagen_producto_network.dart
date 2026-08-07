import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Reemplazo de Image.network para fotos de producto. Image.network no
/// tiene ningún timeout propio: si la conexión se traba a mitad de camino,
/// el pedido se queda esperando para siempre (sin error, sin progreso) y
/// Flutter cachea ese completer pendiente, dejando la foto colgada en
/// cualquier pantalla que la muestre hasta reiniciar la app entera. Acá se
/// baja la foto a mano con timeout explícito, reintento automático (rápido
/// y de fondo) y, si aun así falla, un ícono de "Reintentar" que muestra el
/// motivo real del error. Ver memoria del proyecto (feedback sobre fotos de
/// producto en Super Color/Auto Frenos/Barbería) para la historia completa
/// de por qué está armado así.
class ImagenProductoNetwork extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  // Colores del estado de carga/error: por defecto pensados para fondos
  // claros (formularios, miniaturas), pero el zoom a pantalla completa vive
  // sobre un fondo oscuro y necesita los suyos propios.
  final Color loadingColor;
  final Color iconColor;
  final Color textColor;
  final double iconSize;
  final double textSize;

  const ImagenProductoNetwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loadingColor = const Color(0xFF0F1B3D),
    this.iconColor = const Color(0xFF9CA3AF),
    this.textColor = const Color(0xFF9CA3AF),
    this.iconSize = 20,
    this.textSize = 9,
  });

  // Un solo cliente HTTP compartido para TODAS las fotos de producto de toda
  // la app, nunca se cierra. http.get(...) suelto crea y cierra un Client
  // (y con él, una conexión TCP/TLS nueva) en cada llamada; al abrir varias
  // fotos seguidas eso dispara una ráfaga de handshakes nuevos al mismo
  // host. Reusar un solo cliente con keep-alive evita esas conexiones de
  // más. Mismo cliente usado por precalentar().
  static final http.Client _client = http.Client();

  // Dispara una conexión de calentamiento hacia Firebase Storage al
  // arrancar la app (llamado una vez desde main.dart, sin esperar el
  // resultado). La primera conexión HTTPS a un host nuevo es la que más
  // tarda (resolver el dominio + saludo de seguridad); para cuando el
  // usuario realmente abre una foto, la conexión ya debería estar lista.
  static void precalentar() {
    _client.get(Uri.parse('https://firebasestorage.googleapis.com/')).timeout(const Duration(seconds: 20)).catchError((_) => http.Response('', 0));
  }

  @override
  State<ImagenProductoNetwork> createState() => _ImagenProductoNetworkState();
}

class _ImagenProductoNetworkState extends State<ImagenProductoNetwork> {
  late Future<Uint8List> _future;
  Timer? _reintentoAutomatico;
  int _intentosAutomaticos = 0;
  // Guarda el error real (SocketException, TimeoutException, HTTP xxx, etc.)
  // de la última falla, para poder mostrarlo en vez de solo "Reintentar" —
  // sin esto es imposible saber si lo que está pasando es un timeout, un
  // corte de conexión, un bloqueo de certificado, etc.
  String? _ultimoError;

  @override
  void initState() {
    super.initState();
    _future = _cargarConReintentoDeFondo();
  }

  @override
  void didUpdateWidget(covariant ImagenProductoNetwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _reintentar();
  }

  @override
  void dispose() {
    _reintentoAutomatico?.cancel();
    super.dispose();
  }

  // 4 intentos con espera creciente entre cada uno (2s, 4s, 6s) antes de
  // rendirse y recién ahí mostrar el ícono de "Reintentar". Cada falla queda
  // registrada en _ultimoError (motivo real, no solo "Reintentar" genérico).
  Future<Uint8List> _cargar() async {
    const intentos = 4;
    for (var intento = 1; intento <= intentos; intento++) {
      try {
        final res = await ImagenProductoNetwork._client.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        return res.bodyBytes;
      } catch (e) {
        _ultimoError = _describirError(e);
        if (intento == intentos) rethrow;
        await Future.delayed(Duration(seconds: intento * 2));
      }
    }
    throw Exception('No se pudo cargar la imagen');
  }

  // Traduce la excepción cruda a algo corto y reconocible: el tipo de
  // excepción (SocketException, TimeoutException, HandshakeException, etc.)
  // ya dice mucho de la causa real, más que el genérico "Reintentar".
  String _describirError(Object e) {
    final tipo = e.runtimeType.toString();
    final detalle = e.toString().replaceFirst('$tipo: ', '').replaceFirst('Exception: ', '');
    return detalle.length > 140 ? '$tipo: ${detalle.substring(0, 140)}…' : '$tipo: $detalle';
  }

  // Si los 4 intentos de _cargar() fallan, sigue reintentando solo en
  // segundo plano cada 8s mientras la pantalla siga abierta (hasta 15 veces,
  // ~2 minutos), sin que el usuario tenga que tocar "Reintentar" — la foto
  // debe terminar apareciendo sola apenas la red se recupere.
  Future<Uint8List> _cargarConReintentoDeFondo() {
    final future = _cargar();
    future.then((_) {}, onError: (_) {
      if (!mounted || _intentosAutomaticos >= 15) return;
      _intentosAutomaticos++;
      _reintentoAutomatico = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _future = _cargarConReintentoDeFondo());
      });
    });
    return future;
  }

  void _reintentar() {
    _reintentoAutomatico?.cancel();
    _intentosAutomaticos = 0;
    setState(() => _future = _cargarConReintentoDeFondo());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: widget.loadingColor))),
          );
        }
        if (snapshot.hasError) {
          final mostrarDetalle = (widget.width ?? 200) >= 60;
          return Tooltip(
            // Mantené presionado (o pasá el mouse en Windows) para ver el
            // motivo real del error — útil para reportarlo tal cual.
            message: _ultimoError ?? snapshot.error.toString(),
            child: InkWell(
              onTap: _reintentar,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, color: widget.iconColor, size: widget.iconSize),
                    const SizedBox(height: 2),
                    Text('Reintentar', style: TextStyle(fontSize: widget.textSize, color: widget.textColor)),
                    if (mostrarDetalle && _ultimoError != null) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _ultimoError!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: (widget.textSize - 1).clamp(7, 20), color: widget.textColor.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Image.memory(snapshot.data!, width: widget.width, height: widget.height, fit: widget.fit);
      },
    );
  }
}
