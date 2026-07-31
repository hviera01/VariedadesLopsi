import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

// Los PDFs (ticket de venta, cierre de caja, recibo de abono) usaban la
// fuente Helvetica por defecto del paquete `pdf`, que no viene embebida en
// el archivo: depende de que el visor/driver de impresión tenga su propia
// versión de Helvetica para dibujarla, y en varias impresoras térmicas y
// visores esa sustitución sale con los bordes de las letras borrosos/
// pixelados en vez de nítidos, sobre todo en negrita. Con una fuente TTF
// real embebida en el PDF (Roboto, cargada una sola vez y cacheada acá para
// toda la sesión) el texto se ve igual de nítido en cualquier impresora o
// visor, sin depender de qué fuente tenga instalada.
pw.ThemeData? _temaCacheado;

Future<pw.ThemeData> obtenerTemaPdfConFuenteEmbebida() async {
  final cacheado = _temaCacheado;
  if (cacheado != null) return cacheado;
  final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final tema = pw.ThemeData.withFont(
    base: pw.Font.ttf(regularData),
    bold: pw.Font.ttf(boldData),
  );
  _temaCacheado = tema;
  return tema;
}
