import 'dart:typed_data';
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
Uint8List? _bytesRegular;
Uint8List? _bytesBold;

Future<pw.ThemeData> obtenerTemaPdfConFuenteEmbebida() async {
  final cacheado = _temaCacheado;
  if (cacheado != null) return cacheado;
  final bytes = await obtenerBytesFuenteEmbebida();
  final tema = construirTemaPdfDesdeBytes(bytes);
  _temaCacheado = tema;
  return tema;
}

/// Solo los bytes de la fuente, cacheados igual que [obtenerTemaPdfConFuenteEmbebida].
/// Para un PDF que se arma dentro de un isolate de `compute()` (ver
/// ReporteExportService): `rootBundle` necesita el binding de Flutter, que
/// no existe en un isolate spawneado por `compute()`, así que los bytes hay
/// que cargarlos ANTES, acá en el hilo principal, y recién pasarle el
/// resultado de esto al isolate para que arme el `ThemeData` con
/// [construirTemaPdfDesdeBytes] (esa sí es una función pura, segura en
/// cualquier isolate).
Future<(Uint8List, Uint8List)> obtenerBytesFuenteEmbebida() async {
  final regular = _bytesRegular;
  final bold = _bytesBold;
  if (regular != null && bold != null) return (regular, bold);
  final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final bytesRegular = regularData.buffer.asUint8List();
  final bytesBold = boldData.buffer.asUint8List();
  _bytesRegular = bytesRegular;
  _bytesBold = bytesBold;
  return (bytesRegular, bytesBold);
}

pw.ThemeData construirTemaPdfDesdeBytes((Uint8List, Uint8List) bytes) {
  final (regular, bold) = bytes;
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(ByteData.sublistView(regular)),
    bold: pw.Font.ttf(ByteData.sublistView(bold)),
  );
}
