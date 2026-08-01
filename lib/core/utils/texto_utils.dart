// Antes hacía 6 pasadas de replaceAll (una por cada vocal acentuada + ñ) más
// toLowerCase, cada una recorriendo y realocando el string completo: con
// buscar_producto_dialog llamando esto para cada producto del catálogo en
// cada Enter (ver coincideFuzzy más abajo), esas 6-7 pasadas de más por
// producto eran una buena parte de por qué la búsqueda se sentía lenta con
// catálogos grandes. Con una sola pasada por code unit alcanza.
String normalizarTexto(String texto) {
  final minuscula = texto.toLowerCase();
  final buffer = StringBuffer();
  for (final unidad in minuscula.codeUnits) {
    switch (unidad) {
      case 0xE1: // á
        buffer.writeCharCode(0x61); // a
        break;
      case 0xE9: // é
        buffer.writeCharCode(0x65); // e
        break;
      case 0xED: // í
        buffer.writeCharCode(0x69); // i
        break;
      case 0xF3: // ó
        buffer.writeCharCode(0x6F); // o
        break;
      case 0xFA: // ú
        buffer.writeCharCode(0x75); // u
        break;
      case 0xF1: // ñ
        buffer.writeCharCode(0x6E); // n
        break;
      default:
        buffer.writeCharCode(unidad);
    }
  }
  return buffer.toString().trim();
}

int distanciaLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final matriz = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) matriz[i][0] = i;
  for (var j = 0; j <= b.length; j++) matriz[0][j] = j;
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final costo = a[i - 1] == b[j - 1] ? 0 : 1;
      final opciones = [matriz[i - 1][j] + 1, matriz[i][j - 1] + 1, matriz[i - 1][j - 1] + costo];
      matriz[i][j] = opciones.reduce((v, e) => v < e ? v : e);
    }
  }
  return matriz[a.length][b.length];
}

bool coincideFuzzy(String textoCompleto, String consulta) {
  final textoNorm = normalizarTexto(textoCompleto);
  final consultaNorm = normalizarTexto(consulta);
  if (consultaNorm.isEmpty) return true;
  final palabrasTexto = textoNorm.split(RegExp(r'\s+'));
  final palabrasConsulta = consultaNorm.split(RegExp(r'\s+'));
  for (final palabraConsulta in palabrasConsulta) {
    if (palabraConsulta.isEmpty) continue;
    final coincideAlguna = palabrasTexto.any((palabraTexto) {
      if (palabraTexto.isEmpty) return false;
      // Que la palabra buscada aparezca dentro de una palabra del producto
      // (permite escribir solo el principio o una parte). Antes también se
      // aceptaba al revés (palabra del producto dentro de la búsqueda), lo
      // que hacía que una palabra corta cualquiera del producto -"on", "rex",
      // etc.- calzara adentro de algo como "rexona" y trajera resultados sin
      // ninguna relación real.
      if (palabraTexto.contains(palabraConsulta)) return true;
      // Tolerancia a errores de tipeo: nada para palabras muy cortas (ahí
      // cualquier letra distinta ya es otra palabra), un poco más para
      // palabras largas.
      final tolerancia = palabraConsulta.length <= 4 ? 0 : (palabraConsulta.length <= 7 ? 1 : 2);
      if (tolerancia == 0) return false;
      return distanciaLevenshtein(palabraTexto, palabraConsulta) <= tolerancia;
    });
    if (!coincideAlguna) return false;
  }
  return true;
}