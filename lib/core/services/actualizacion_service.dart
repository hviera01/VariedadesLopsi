import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../version_app.dart';

class ActualizacionDisponible {
  final int version;
  final String urlDescarga;
  final String notas;

  ActualizacionDisponible({required this.version, required this.urlDescarga, required this.notas});
}

/// Chequea si hay una versión más nueva de la app publicada como GitHub
/// Release (el instalador/APK se sube a mano con `gh release create`, ver
/// memoria del proyecto) y, si el usuario acepta, la descarga y la instala.
/// Aplica a Windows (.exe) y Android (.apk); en Web no hay nada que
/// instalar. GitHub Releases es público así que no hace falta ningún token
/// para leerlo.
class ActualizacionService {
  static const _repo = 'hviera01/VariedadesLopsi';
  // Público para que side_menu.dart pueda armar el link "Abrir página" de
  // respaldo cuando el chequeo automático falla (ver _buscarActualizaciones).
  static const repoUrl = _repo;

  static bool get aplica => !kIsWeb && (Platform.isWindows || Platform.isAndroid);

  static String get _extensionEsperada => Platform.isAndroid ? '.apk' : '.exe';

  /// Última versión publicada como GitHub Release, sin importar si es más
  /// nueva que la instalada (a diferencia de buscarActualizacion()). Null si
  /// no hay internet o GitHub no responde. La usa la pantalla de
  /// Dispositivos para marcar como desactualizado cualquier equipo que
  /// reportó una versión menor a esta.
  static Future<int?> obtenerUltimaVersionPublicada() async {
    try {
      final respuesta = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return null;
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final tag = (datos['tag_name'] as String? ?? '').replaceFirst('v', '');
      return int.tryParse(tag);
    } catch (_) {
      return null;
    }
  }

  /// Devuelve null si no aplica, si no hay un asset para esta plataforma, o
  /// si la versión publicada no es más nueva que la instalada -en esos casos
  /// no hay que interrumpir el uso normal de la app-. A diferencia de antes,
  /// un fallo real de red/API (sin internet, GitHub no responde, IP con
  /// rate-limit de la API pública, etc.) YA NO se traga en silencio devolviendo
  /// null: eso hacía que el chequeo manual ("Buscar actualizaciones") le
  /// dijera al usuario "ya tenés la última versión" aunque en realidad el
  /// chequeo ni siquiera se pudo completar -reportado en un equipo donde el
  /// chequeo automático cada 10 min tampoco detectaba versiones nuevas ya
  /// publicadas-. Ahora esos casos lanzan una excepción, para que quien
  /// llama pueda distinguir "confirmado, estás al día" de "no se pudo
  /// revisar". El chequeo automático periódico (ver AppShell) sigue
  /// ignorando el error en silencio -no tiene sentido interrumpir con un
  /// diálogo cada 10 minutos-, pero el botón "Buscar actualizaciones" sí le
  /// avisa al usuario cuál de los dos casos fue.
  static Future<ActualizacionDisponible?> buscarActualizacion() async {
    if (!aplica) return null;
    try {
      return await _buscarViaApi();
    } catch (errorApi) {
      // api.github.com (la API JSON) puede estar bloqueada, con rate-limit,
      // o simplemente inalcanzable en algunas redes -reportado en un equipo
      // donde el chequeo automático nunca detectaba versiones ya publicadas,
      // aunque la PC sí tenía internet normal-. github.com (el sitio, no la
      // API) suele ser mucho más difícil de bloquear porque es el mismo host
      // que usa cualquiera para entrar a GitHub desde el navegador. Como
      // último recurso antes de rendirse, se prueba detectar la versión
      // mirando a dónde redirige /releases/latest ahí, sin pasar por la API.
      try {
        return await _buscarViaRedireccion();
      } catch (errorRedireccion) {
        throw Exception('api.github.com: $errorApi · github.com: $errorRedireccion');
      }
    }
  }

  static Future<ActualizacionDisponible?> _buscarViaApi() async {
    final respuesta = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 12));
    if (respuesta.statusCode != 200) {
      throw Exception('GitHub respondió con error ${respuesta.statusCode} al buscar la última versión');
    }
    final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final tag = (datos['tag_name'] as String? ?? '').replaceFirst('v', '');
    final version = int.tryParse(tag);
    if (version == null || version <= versionApp) return null;
    final assets = (datos['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    Map<String, dynamic>? asset;
    for (final a in assets) {
      if ((a['name'] as String? ?? '').toLowerCase().endsWith(_extensionEsperada)) {
        asset = a;
        break;
      }
    }
    final url = asset?['browser_download_url'] as String?;
    if (url == null) return null;
    return ActualizacionDisponible(
      version: version,
      urlDescarga: url,
      notas: (datos['body'] as String? ?? '').trim(),
    );
  }

  /// Fallback sin api.github.com: `github.com/<repo>/releases/latest` hace un
  /// 302 a `.../releases/tag/vN`, así que el número de versión se puede leer
  /// del header `Location` sin necesitar la API. Sin la API tampoco hay lista
  /// de assets ni notas: se arma la URL de descarga con el mismo patrón de
  /// nombre que se usa siempre al publicar (`Lopsi<version>.exe`/`.apk`, ver
  /// memoria del proyecto) y se confirma con una petición HEAD que el asset
  /// realmente exista antes de ofrecerlo, para no mandar a descargar un link
  /// roto si алgún día se publica con otro nombre.
  static Future<ActualizacionDisponible?> _buscarViaRedireccion() async {
    final cliente = http.Client();
    try {
      final pedido = http.Request('GET', Uri.parse('https://github.com/$_repo/releases/latest'))..followRedirects = false;
      final respuesta = await cliente.send(pedido).timeout(const Duration(seconds: 12));
      final ubicacion = respuesta.headers['location'];
      if (ubicacion == null) {
        throw Exception('github.com no devolvió una redirección (HTTP ${respuesta.statusCode})');
      }
      final match = RegExp(r'/releases/tag/v(\d+)$').firstMatch(ubicacion);
      final version = match != null ? int.tryParse(match.group(1)!) : null;
      if (version == null) throw Exception('No se pudo leer la versión desde: $ubicacion');
      if (version <= versionApp) return null;

      final nombreAsset = Platform.isAndroid ? 'Lopsi$version.apk' : 'Lopsi$version.exe';
      final urlDescarga = 'https://github.com/$_repo/releases/download/v$version/$nombreAsset';
      final chequeoAsset = await cliente.head(Uri.parse(urlDescarga)).timeout(const Duration(seconds: 12));
      if (chequeoAsset.statusCode != 200 && chequeoAsset.statusCode != 302) {
        throw Exception('El asset esperado ($nombreAsset) no existe en la release v$version');
      }
      return ActualizacionDisponible(version: version, urlDescarga: urlDescarga, notas: '');
    } finally {
      cliente.close();
    }
  }

  /// Descarga el instalador/APK a una carpeta temporal y lo instala.
  ///
  /// En Windows, el instalador de Inno Setup (mismo AppId que la instalación
  /// actual) reemplaza los archivos solo -por eso acá se cierra esta
  /// instancia (exit) apenas queda lanzado, para no competir por los
  /// archivos que está por sobrescribir-.
  ///
  /// En Android no hay forma de instalar sin que el usuario confirme (una
  /// restricción del sistema operativo, no hay vuelta): esto abre la
  /// pantalla del instalador de Android con el APK descargado, y ahí el
  /// usuario decide si instala. La app sigue corriendo mientras tanto.
  static Future<void> descargarEInstalar(
    ActualizacionDisponible actualizacion,
    void Function(double progreso) onProgreso,
  ) async {
    final carpetaTemp = await getTemporaryDirectory();
    final nombreArchivo = Platform.isAndroid ? 'LopsiActualizacion_v${actualizacion.version}.apk' : 'LopsiActualizacion_v${actualizacion.version}.exe';
    final archivoDestino = File('${carpetaTemp.path}${Platform.pathSeparator}$nombreArchivo');

    final cliente = http.Client();
    try {
      final peticion = await cliente.send(http.Request('GET', Uri.parse(actualizacion.urlDescarga)));
      final total = peticion.contentLength ?? 0;
      var recibido = 0;
      final sink = archivoDestino.openWrite();
      await for (final trozo in peticion.stream) {
        sink.add(trozo);
        recibido += trozo.length;
        if (total > 0) onProgreso(recibido / total);
      }
      await sink.close();
    } finally {
      cliente.close();
    }

    if (Platform.isAndroid) {
      await OpenFile.open(archivoDestino.path);
      return;
    }

    await Process.start(archivoDestino.path, [], mode: ProcessStartMode.detached);
    exit(0);
  }
}
