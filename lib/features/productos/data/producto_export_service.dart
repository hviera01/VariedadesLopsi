import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart' as bc;
import 'producto_model.dart';
import '../../../core/utils/formato_moneda.dart';
import '../../negocio/data/negocio_model.dart';

class ProductoExportService {
  static pw.MemoryImage? _cacheIconoPulgar;

  Future<pw.MemoryImage> _cargarIconoPulgar() async {
    final cacheado = _cacheIconoPulgar;
    if (cacheado != null) return cacheado;
    final data = await rootBundle.load('assets/images/icono_pulgar.png');
    final imagen = pw.MemoryImage(data.buffer.asUint8List());
    _cacheIconoPulgar = imagen;
    return imagen;
  }
  Uint8List generarExcel(List<ProductoModel> lista, Map<String, String> mapaCategorias) {
    final libro = xls.Excel.createExcel();
    final hoja = libro['Inventario'];
    libro.delete('Sheet1');

    hoja.appendRow([
      xls.TextCellValue('Código'),
      xls.TextCellValue('Nombre'),
      xls.TextCellValue('Descripción'),
      xls.TextCellValue('Categoría'),
      xls.TextCellValue('Existencia'),
      xls.TextCellValue('Precio Venta'),
      xls.TextCellValue('Precio Compra'),
      xls.TextCellValue('Estado'),
    ]);

    for (final p in lista) {
      hoja.appendRow([
        xls.TextCellValue(p.codigo),
        xls.TextCellValue(p.nombre),
        xls.TextCellValue(p.descripcion),
        xls.TextCellValue(mapaCategorias[p.idCategoria] ?? '-'),
        xls.TextCellValue(p.stock.toString()),
        xls.TextCellValue(formatearMoneda(p.precioVenta)),
        xls.TextCellValue(formatearMoneda(p.precioCompra)),
        xls.TextCellValue(p.estado ? 'Activo' : 'Inactivo'),
      ]);
    }

    final bytes = libro.save();
    return Uint8List.fromList(bytes ?? []);
  }

  Future<Uint8List> generarPdfInventario(List<ProductoModel> lista, Map<String, String> mapaCategorias) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Inventario · VARIEDADES LOPSI', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F1B3D))),
            pw.SizedBox(height: 4),
            pw.Text('Total de productos: ${lista.length}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 14),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Código', 'Nombre', 'Descripción', 'Categoría', 'Existencia', 'P. Venta', 'P. Compra', 'Estado'],
            data: lista.map((p) {
              return [
                p.codigo,
                p.nombre,
                p.descripcion.isEmpty ? '-' : p.descripcion,
                mapaCategorias[p.idCategoria] ?? '-',
                p.stock.toString(),
                formatearMoneda(p.precioVenta),
                formatearMoneda(p.precioCompra),
                p.estado ? 'Activo' : 'Inactivo',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F1B3D)),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF0)),
            border: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(2.4),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.3),
              6: const pw.FlexColumnWidth(1.3),
              7: const pw.FlexColumnWidth(1.1),
            },
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> generarPdfTicket(
    List<ProductoModel> lista,
    Map<String, String> mapaCategorias,
    Set<String> campos,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('VARIEDADES LOPSI', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('Listado de Inventario', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 8),
              pw.Divider(),
              ...lista.map((p) {
                final lineas = <pw.Widget>[];
                if (campos.contains('codigo')) lineas.add(pw.Text('Código: ${p.codigo}', style: const pw.TextStyle(fontSize: 8)));
                lineas.add(pw.Text(p.nombre, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
                if (campos.contains('descripcion') && p.descripcion.isNotEmpty) {
                  lineas.add(pw.Text(p.descripcion, style: const pw.TextStyle(fontSize: 7.5)));
                }
                if (campos.contains('categoria')) {
                  lineas.add(pw.Text('Categoría: ${mapaCategorias[p.idCategoria] ?? '-'}', style: const pw.TextStyle(fontSize: 7.5)));
                }
                if (campos.contains('existencia')) {
                  lineas.add(pw.Text('Existencia: ${p.stock}', style: const pw.TextStyle(fontSize: 7.5)));
                }
                if (campos.contains('precioVenta')) {
                  lineas.add(pw.Text('P. Venta: ${formatearMoneda(p.precioVenta)}', style: const pw.TextStyle(fontSize: 7.5)));
                }
                if (campos.contains('precioCompra')) {
                  lineas.add(pw.Text('P. Compra: ${formatearMoneda(p.precioCompra)}', style: const pw.TextStyle(fontSize: 7.5)));
                }
                lineas.add(pw.SizedBox(height: 6));
                lineas.add(pw.Divider());
                return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: lineas);
              }),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// Etiquetas de código de barras, mismo diseño y medidas que el sistema
  /// viejo (`frmProducto.GenerarPrintDocumentCodigoBarras`): página de 3x3
  /// pulgadas (76.2x76.2mm) con hasta 3 etiquetas apiladas por página
  /// -`cantidadEtiquetas = 3` hardcodeado ahí-, cada una con el nombre del
  /// negocio + el ícono de pulgar arriba, el código de barras (alto 0.35in
  /// = 25pt), el código en texto, el nombre del producto en itálica chica,
  /// y un recuadro alrededor de todo. [cantidad] es el TOTAL de etiquetas a
  /// imprimir (igual que "¿Cuántas etiquetas desea imprimir?" del sistema
  /// viejo): si pide 3, sale 1 sola página con esas 3; si pide 4, sale una
  /// página con 3 y una segunda con 1 sola.
  Future<Uint8List> generarPdfCodigoBarras(ProductoModel producto, NegocioModel negocio, {int cantidad = 1}) async {
    const etiquetasPorPagina = 3;
    final codigo = producto.codigoBarras.isNotEmpty ? producto.codigoBarras : producto.codigo;
    final iconoPulgar = await _cargarIconoPulgar();
    final nombreNegocio = negocio.nombre.isEmpty ? 'MI NEGOCIO' : negocio.nombre.toUpperCase();
    final doc = pw.Document();

    pw.Widget etiqueta() {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(nombreNegocio, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 3),
                pw.Image(iconoPulgar, height: 10),
              ],
            ),
            pw.SizedBox(height: 2),
            // 25pt = 0.35in, igual que barcodeHeight del sistema viejo. El
            // ancho (150pt) también se achicó de 180 -no lo fija el sistema
            // viejo, pero con 180 solo entraban 2 etiquetas por página en
            // vez de las 3 que deben ir-.
            pw.BarcodeWidget(barcode: bc.Barcode.code128(), data: codigo, width: 150, height: 25, drawText: false),
            pw.SizedBox(height: 2),
            pw.Text(codigo, style: const pw.TextStyle(fontSize: 7)),
            if (producto.nombre.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                producto.nombre,
                style: pw.TextStyle(fontSize: 5, fontStyle: pw.FontStyle.italic),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ],
          ],
        ),
      );
    }

    var restantes = cantidad;
    while (restantes > 0) {
      final enEstaPagina = restantes >= etiquetasPorPagina ? etiquetasPorPagina : restantes;
      restantes -= enEstaPagina;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(76.2 * PdfPageFormat.mm, 76.2 * PdfPageFormat.mm, marginAll: 10),
          build: (context) => pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: List.generate(enEstaPagina, (_) => etiqueta()),
          ),
        ),
      );
    }
    return doc.save();
  }
}