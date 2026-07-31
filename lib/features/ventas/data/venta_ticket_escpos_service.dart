import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'venta_model.dart';
import 'numero_a_letras.dart';
import 'tipos_documento.dart';
import '../../../core/utils/formato_moneda.dart';
import '../../negocio/data/negocio_model.dart';

/// Genera el mismo contenido del ticket térmico de `generarPdfFactura` (ver
/// VentaExportService) pero como comandos ESC/POS crudos, para mandarlos
/// directo a una impresora de red (ImpresoraRedService) en vez de un PDF —
/// es la vía de impresión que funciona desde el celular.
class VentaTicketEscPosService {
  // Ícono de "pulgar arriba" fijo del paquete (no viene de Firestore como el
  // logo del negocio), se decodifica una sola vez y queda en cache.
  static img.Image? _cacheIconoPulgar;

  Future<img.Image> _cargarIconoPulgar() async {
    final cacheado = _cacheIconoPulgar;
    if (cacheado != null) return cacheado;
    final data = await rootBundle.load('assets/images/icono_pulgar.png');
    final decodificado = img.decodeImage(data.buffer.asUint8List())!;
    // A resolución completa (256x256) el ícono queda enorme en el rollo
    // térmico; se reduce a un alto chico, similar al de la versión PDF.
    final chico = img.copyResize(decodificado, height: 60);
    _cacheIconoPulgar = chico;
    return chico;
  }

  Future<double?> _obtenerPuntosTotales(VentaModel venta) async {
    if (venta.puntosGanados <= 0 || venta.idCliente.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('clientes').doc(venta.idCliente).get();
      return ((snap.data()?['saldoPuntos'] ?? 0) as num).toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> generarTicket(VentaModel venta, NegocioModel negocio) async {
    final perfil = await CapabilityProfile.load();
    final generador = Generator(PaperSize.mm80, perfil);
    final formatoFecha = DateFormat('dd/MM/yyyy HH:mm');
    final formatoDia = DateFormat('dd/MM/yyyy');
    final iconoPulgar = await _cargarIconoPulgar();
    // El logo del negocio (base64, igual que en el PDF) no se imprimía nunca
    // acá — a diferencia de generarPdfFactura, que sí lo incluye.
    img.Image? logo;
    if (negocio.logoBnBase64.isNotEmpty) {
      try {
        final decodificado = img.decodeImage(base64Decode(negocio.logoBnBase64));
        if (decodificado != null) logo = img.copyResize(decodificado, width: decodificado.width >= decodificado.height ? 300 : null, height: decodificado.height > decodificado.width ? 300 : null);
      } catch (_) {
        logo = null;
      }
    }
    final puntosTotales = await _obtenerPuntosTotales(venta);
    // Todo lo fiscal (CAI, rango autorizado, desglose de ISV, leyenda legal)
    // solo tiene sentido en una Factura/Boleta formal. Una Venta normal (la
    // que usa este negocio siempre) es un comprobante simple, sin nada de
    // esto.
    final esFacturable = venta.tipoDocumento == 'Factura' || venta.tipoDocumento == 'Boleta';

    double precioMostrado(dynamic item) => negocio.facturaPreciosConIsv ? redondearMoneda((item.precioVenta as double) * 1.15) : item.precioVenta as double;
    double importeMostrado(dynamic item) {
      if (!negocio.facturaPreciosConIsv) return item.subtotal as double;
      final precio = precioMostrado(item);
      return redondearMoneda(precio * (item.cantidad as double) * (1 - (item.descuentoPorcentaje as double) / 100));
    }

    List<int> bytes = [];
    bytes += generador.reset();

    if (logo != null) {
      bytes += generador.image(logo, align: PosAlign.center);
      bytes += generador.feed(1);
    }
    if (negocio.nombre.isNotEmpty) {
      bytes += generador.text(negocio.nombre.toUpperCase(), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    }
    // Ícono de "pulgar arriba" junto al nombre del negocio, igual que el
    // sistema viejo — ESC/POS no permite combinar texto e imagen en el mismo
    // renglón, así que se imprime chico e inmediatamente debajo del nombre.
    bytes += generador.image(iconoPulgar, align: PosAlign.center);
    if (negocio.eslogan.isNotEmpty) bytes += generador.text(negocio.eslogan, styles: const PosStyles(align: PosAlign.center));
    bytes += generador.text('Celulares, Accesorios y Otros Productos Más', styles: const PosStyles(align: PosAlign.center));
    if (negocio.direccion.isNotEmpty) bytes += generador.text('Dirección: ${negocio.direccion}', styles: const PosStyles(align: PosAlign.center));
    if (negocio.rtn.isNotEmpty) bytes += generador.text('RTN: ${negocio.rtn}', styles: const PosStyles(align: PosAlign.center));
    if (negocio.telefono.isNotEmpty) bytes += generador.text('WhatsApp: ${negocio.telefono}', styles: const PosStyles(align: PosAlign.center));
    if (negocio.correo.isNotEmpty) bytes += generador.text('Email: ${negocio.correo}', styles: const PosStyles(align: PosAlign.center));
    if (esFacturable && negocio.cai.isNotEmpty) bytes += generador.text('CAI: ${negocio.cai}', styles: const PosStyles(align: PosAlign.center));
    bytes += generador.text('Síguenos en nuestras redes sociales:', styles: const PosStyles(align: PosAlign.center));
    bytes += generador.text('Facebook: Variedades LOPSI', styles: const PosStyles(align: PosAlign.center));
    bytes += generador.text('Instagram: @variedadeslopsi', styles: const PosStyles(align: PosAlign.center));
    bytes += generador.text('TikTok: @variedades.lopsi', styles: const PosStyles(align: PosAlign.center));
    bytes += generador.hr();

    bytes += generador.text('${(tiposDocumento[venta.tipoDocumento] ?? venta.tipoDocumento).toUpperCase()} ${negocio.rangoPrefijo}${venta.numeroDocumento}', styles: const PosStyles(bold: true));
    bytes += generador.text('Fecha: ${venta.fechaRegistro != null ? formatoFecha.format(venta.fechaRegistro!) : '-'}');
    bytes += generador.text('Atendido por: ${venta.usuarioRegistro}');
    bytes += generador.text('Condición: ${venta.condicion}');
    if (venta.condicion == 'Credito' && venta.fechaVencimiento != null) {
      bytes += generador.text('Fecha de vencimiento: ${formatoDia.format(venta.fechaVencimiento!)}');
    }
    bytes += generador.hr();

    bytes += generador.text('Cliente: ${venta.nombreCliente.isEmpty ? 'CONSUMIDOR FINAL' : venta.nombreCliente}');
    if (esFacturable) {
      bytes += generador.text('ID/RTN Cliente: ${venta.documentoCliente.isEmpty ? 'N/A' : venta.documentoCliente}');
      if (venta.oc.isNotEmpty) bytes += generador.text('No. O/C exenta: ${venta.oc}');
      if (venta.regExonerado.isNotEmpty) bytes += generador.text('No. Reg de exonerado: ${venta.regExonerado}');
      if (venta.regSag.isNotEmpty) bytes += generador.text('No. De reg de la SAG: ${venta.regSag}');
    }
    bytes += generador.hr();

    for (final item in venta.detalle) {
      bytes += generador.text(item.nombreProducto);
      bytes += generador.row([
        PosColumn(text: '${_formatoCantidad(item.cantidad)} x ${formatearMoneda(precioMostrado(item))}${item.descuentoPorcentaje > 0 ? ' (-${_formatoCantidad(item.descuentoPorcentaje)}%)' : ''}', width: 8),
        PosColumn(text: formatearMoneda(importeMostrado(item)), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generador.hr();

    // SUBTOTAL / Descuentos / TOTAL A PAGAR se muestran siempre, igual que
    // el ticket viejo ("Descuentos" fijo en 0.00, no calculado).
    bytes += _filaTotal(generador, 'SUBTOTAL:', venta.subtotal);
    if (venta.descuentoGlobal > 0) bytes += generador.text('Descuento global: ${_formatoCantidad(venta.descuentoGlobal)}%');
    bytes += _filaTotal(generador, 'Descuentos:', 0);
    if (esFacturable) {
      bytes += _filaTotal(generador, 'Gravado 15%:', venta.subtotal);
      bytes += _filaTotal(generador, 'ISV 15%:', venta.impuesto);
    }
    bytes += _filaTotal(generador, 'TOTAL A PAGAR:', venta.totalAPagar, negrita: true);
    bytes += generador.hr();

    bytes += generador.text('Son: ${convertirNumeroALetras(venta.totalAPagar)}');
    if (venta.condicion != 'Credito') {
      if (venta.metodoPago == 'Efectivo') {
        bytes += generador.text('Efectivo: ${formatearMoneda(venta.montoPago)}');
        bytes += generador.text('Cambio: ${formatearMoneda(venta.montoCambio)}');
      } else if (venta.metodoPago == 'Tarjeta') {
        bytes += generador.text('Terminal POS: ${formatearMoneda(venta.totalAPagar)}');
      } else if (venta.metodoPago == 'Transferencia') {
        bytes += generador.text('Transferencia');
      } else if (venta.metodoPago == 'Mixto') {
        for (final pago in venta.pagosMixtos) {
          bytes += generador.text('${pago.metodoPago}: ${formatearMoneda(pago.monto)}');
        }
      }
    }
    if (venta.puntosGanados > 0) {
      bytes += generador.hr();
      bytes += generador.text('Puntos Ganados: ${venta.puntosGanados.toStringAsFixed(0)}');
      if (puntosTotales != null) bytes += generador.text('Total de Puntos: ${puntosTotales.toStringAsFixed(0)}');
    }
    bytes += generador.hr();

    if (esFacturable) {
      if (negocio.rangoPrefijo.isNotEmpty || negocio.rangoDesde.isNotEmpty) {
        bytes += generador.text('Rango Aut.: ${negocio.rangoPrefijo}${negocio.rangoDesde} al ${negocio.rangoPrefijo}${negocio.rangoHasta}');
      }
      if (negocio.fechaLimiteEmision != null) {
        bytes += generador.text('Fecha Límite: ${formatoDia.format(negocio.fechaLimiteEmision!)}');
      }
      bytes += generador.text('ORIGINAL: CLIENTE');
      bytes += generador.text('COPIA: OBLIGADO TRIBUTARIO EMISOR');
      bytes += generador.text('LA FACTURA ES BENEFICIO DE TODOS, ¡EXÍJALA!', styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    bytes += generador.text('¡GRACIAS POR SU COMPRA!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generador.cut();

    return bytes;
  }

  List<int> _filaTotal(Generator generador, String etiqueta, double valor, {bool negrita = false}) {
    return generador.row([
      PosColumn(text: etiqueta, width: 8, styles: PosStyles(bold: negrita)),
      PosColumn(text: formatearMoneda(valor), width: 4, styles: PosStyles(align: PosAlign.right, bold: negrita)),
    ]);
  }

  String _formatoCantidad(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
    return cantidad.toStringAsFixed(2);
  }
}
