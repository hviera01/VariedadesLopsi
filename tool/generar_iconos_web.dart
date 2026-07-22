// Genera el favicon y los iconos PWA de web/ (favicon.png, web/icons/*.png)
// a partir de assets/images/logo.png. Se corre una sola vez a mano:
// `dart run tool/generar_iconos_web.dart`.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.png').readAsBytesSync();
  final original = img.decodePng(bytes);
  if (original == null) {
    stderr.writeln('No se pudo leer assets/images/logo.png');
    exit(1);
  }
  final cuadrado = img.copyResizeCropSquare(original, size: original.width < original.height ? original.width : original.height);

  void guardar(String ruta, int tamano) {
    final redimensionado = img.copyResize(cuadrado, width: tamano, height: tamano, interpolation: img.Interpolation.average);
    File(ruta).writeAsBytesSync(img.encodePng(redimensionado));
    // ignore: avoid_print
    print('Listo: $ruta ($tamano x $tamano)');
  }

  guardar('web/favicon.png', 32);
  guardar('web/icons/Icon-192.png', 192);
  guardar('web/icons/Icon-512.png', 512);
  guardar('web/icons/Icon-maskable-192.png', 192);
  guardar('web/icons/Icon-maskable-512.png', 512);
}
