import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/splash_screen.dart';
import 'features/ventas/presentation/screens/escaneo_remoto_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sin esto, un error al construir cualquier pantalla deja esa área
  // completamente en blanco (en release Flutter oculta el detalle);
  // con esto al menos se ve un mensaje en vez de un blanco silencioso.
  ErrorWidget.builder = (details) => Container(
        color: Colors.white,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Ocurrió un error al mostrar esta pantalla:\n${details.exception}',
          style: const TextStyle(color: Colors.red, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
  // OJO: este flag en `false` se agregó para evitar que google_fonts baje
  // variantes de Poppins por red en cajas con internet lento — la intención
  // era que, si la variante no está en caché local, cayera al font del
  // sistema. En la práctica (google_fonts 8.x) no cae con gracia: tira una
  // excepción no capturada apenas se pide una variante que nunca se
  // descargó/cacheó antes (por ejemplo, la primera vez que se abre una
  // pantalla que usa un peso de fuente distinto, o después de limpiar el
  // caché del navegador en la versión web) — dejando esa pantalla en blanco.
  // Se deja en `true` (el default del paquete): sí puede pedir la fuente por
  // red la primera vez, pero una vez bajada queda cacheada localmente y no
  // vuelve a pedirla — mejor que un crash duro.
  GoogleFonts.config.allowRuntimeFetching = true;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: SistemaVentasApp()));
}

class SistemaVentasApp extends StatelessWidget {
  const SistemaVentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El QR que muestra la PC para usar el celular como lector de código de
    // barras (ver EscanearRemotoDialog) apunta a esta misma URL con
    // "?escanear=CODIGO". Si viene ese parámetro, se salta el login por
    // completo y se va directo a la cámara: cualquier celular tiene que
    // poder ayudar a escanear sin necesitar una cuenta en el sistema.
    final codigoEscaneo = Uri.base.queryParameters['escanear'];

    return MaterialApp(
      title: 'Sistema Ventas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F1B3D),
        useMaterial3: true,
      ),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: codigoEscaneo != null && codigoEscaneo.isNotEmpty
          ? EscaneoRemotoScreen(codigo: codigoEscaneo)
          : const SplashScreen(siguiente: AuthGate()),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.usuario == null) {
      return const LoginScreen();
    }

    return const AppShell();
  }
}