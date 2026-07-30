import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'celular_model.dart';
import '../../negocio/data/negocio_model.dart';
import '../../../core/utils/logo_pdf.dart';

/// Genera la "Nota de Garantía" de un celular vendido: ticket térmico de
/// 80mm, mismo patrón que el ticket de venta (VentaExportService), impreso
/// dos veces (Original y Copia).
class CelularGarantiaExportService {
  static const _condiciones = [
    'No cubre daños por golpes, caídas o líquidos.',
    'No cubre mal uso o manipulación por terceros no autorizados.',
    'Aplica solo a defectos de fábrica.',
    'Debe presentar esta nota de garantía junto con el equipo.',
    'No cubre accesorios (cargador, cable, funda) salvo que se indique lo contrario.',
  ];

  Future<Uint8List> generarPdfGarantia(CelularModel celular, NegocioModel negocio) async {
    final doc = pw.Document();
    final logo = decodificarLogoPdf(negocio.logoBnBase64, maxDimension: 400);

    doc.addPage(_construirPagina(celular, negocio, logo, esCopia: false));
    doc.addPage(_construirPagina(celular, negocio, logo, esCopia: true));

    return doc.save();
  }

  pw.Page _construirPagina(CelularModel celular, NegocioModel negocio, pw.MemoryImage? logo, {required bool esCopia}) {
    final formatoFecha = DateFormat('dd/MM/yyyy');
    const fSmall = 7.5;
    const fNormal = 8.5;
    // Altura estimada generosa: mejor que sobre papel en blanco a que
    // MultiPage tenga que partir la nota en dos páginas.
    const alturaMm = 190.0;
    const anchoMm = 80.0;
    const margenMm = 5.0;

    return pw.Page(
      pageFormat: PdfPageFormat(anchoMm * PdfPageFormat.mm, alturaMm * PdfPageFormat.mm, marginAll: margenMm * PdfPageFormat.mm),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Center(child: pw.Image(logo, width: 110)),
            if (negocio.nombre.isNotEmpty)
              pw.Center(child: pw.Text(negocio.nombre.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            if (negocio.direccion.isNotEmpty)
              pw.Center(child: pw.Text(negocio.direccion, style: const pw.TextStyle(fontSize: fSmall), textAlign: pw.TextAlign.center)),
            if (negocio.telefono.isNotEmpty)
              pw.Center(child: pw.Text('Tel: ${negocio.telefono}', style: const pw.TextStyle(fontSize: fSmall))),
            pw.SizedBox(height: 6),
            _separador(),
            pw.Center(
              child: pw.Text(
                'NOTA DE GARANTÍA — ${esCopia ? 'COPIA' : 'ORIGINAL'}',
                style: pw.TextStyle(fontSize: fNormal, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Center(child: pw.Text('Vigencia: 30 días desde la fecha de venta', style: const pw.TextStyle(fontSize: fSmall))),
            _separador(),
            _dato('IMEI', celular.imei),
            _dato('Marca', celular.marca),
            _dato('Modelo', celular.modelo),
            _dato('Color', celular.color),
            _dato('Fecha de venta', celular.fechaVenta != null ? formatoFecha.format(celular.fechaVenta!) : '-'),
            _dato('Cliente', celular.nombreClienteFinal.isEmpty ? '-' : celular.nombreClienteFinal),
            _separador(),
            pw.Text('Condiciones de la garantía:', style: pw.TextStyle(fontSize: fNormal, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            ..._condiciones.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('•  ', style: const pw.TextStyle(fontSize: fSmall)),
                      pw.Expanded(child: pw.Text(c, style: const pw.TextStyle(fontSize: fSmall))),
                    ],
                  ),
                )),
            pw.SizedBox(height: 18),
            pw.Center(child: pw.Text('_____________________', style: const pw.TextStyle(fontSize: fNormal))),
            pw.Center(child: pw.Text('Firma del Cliente', style: const pw.TextStyle(fontSize: fSmall))),
            pw.SizedBox(height: 16),
            pw.Center(child: pw.Text('_____________________', style: const pw.TextStyle(fontSize: fNormal))),
            pw.Center(child: pw.Text('Firma del Negocio', style: const pw.TextStyle(fontSize: fSmall))),
            pw.SizedBox(height: 12),
            _separador(),
            pw.Center(child: pw.Text('¡Gracias por confiar en nosotros!', style: pw.TextStyle(fontSize: fNormal, fontWeight: pw.FontWeight.bold))),
          ],
        );
      },
    );
  }

  pw.Widget _dato(String etiqueta, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$etiqueta: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: valor, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  pw.Widget _separador() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Divider(thickness: 0.7),
    );
  }
}
