import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/livraison_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/home_client.dart';
import 'screens/livreur/home_livreur.dart';
import 'screens/receptionniste/home_receptionniste.dart';
import 'screens/admin/home_admin.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const TchiraApp());
}

class TchiraApp extends StatelessWidget {
  const TchiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LivraisonProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _TchiraMaterialApp(),
    );
  }
}

// Widget séparé pour pouvoir écouter ThemeProvider via context.watch
class _TchiraMaterialApp extends StatelessWidget {
  const _TchiraMaterialApp();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      title:                      'Tchira Express',
      debugShowCheckedModeBanner: false,
      themeMode:                  themeMode,

      // ── Thème clair ───────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme:  ColorScheme.fromSeed(seedColor: const Color(0xFF0D7377)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      ),

      // ── Thème sombre ──────────────────────────────────────────────────────
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:   const Color(0xFF0D7377),
          brightness:  Brightness.dark,
        ),
        useMaterial3:            true,
        brightness:              Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor:               const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D7377),
          foregroundColor: Colors.white,
        ),
      ),

      home: const SplashDecision(),
    );
  }
}

// ─── SplashDecision ────────────────────────────────────────────────────────────
// Logique de démarrage :
// 1. Onboarding jamais vu → OnboardingScreen (1 seule fois à l'installation)
// 2. Token présent + session valide → HomeScreen du rôle (sans redemander login)
// 3. Pas de token → LoginScreen
class SplashDecision extends StatefulWidget {
  const SplashDecision({super.key});
  @override
  State<SplashDecision> createState() => _SplashDecisionState();
}

class _SplashDecisionState extends State<SplashDecision> {
  @override
  void initState() {
    super.initState();
    _decider();
  }

  Future<void> _decider() async {
    final prefs     = await SharedPreferences.getInstance();
    if (!mounted) return;
    final auth      = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    // ── 1. Onboarding vu pour la première fois ? ──────────────────────────
    final onboardingVu = prefs.getBool('onboarding_vu') ?? false;
    if (!onboardingVu) {
      navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    // ── 2. Restaurer la session (token + profil depuis prefs + vérif serveur) ──
    await auth.restaurerSession();
    if (!mounted) return;

    // ── 3. Pas connecté → Login ───────────────────────────────────────────
    if (!auth.estConnecte) {
      navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // ── 4. Connecté → écran selon le rôle, sans passer par Login ─────────
    Widget ecran;
    switch (auth.user?.role) {
      case 'admin':          ecran = const HomeAdmin();           break;
      case 'livreur':        ecran = const HomeLibreur();         break;
      case 'receptionniste': ecran = const HomeReceptionniste();  break;
      default:               ecran = const HomeClient();
    }

    if (!mounted) return;
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => ecran));
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement pendant la décision
    return const Scaffold(
      backgroundColor: Color(0xFF0D7377),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🚀', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Tchira Express',
                style: TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white70),
          ],
        ),
      ),
    );
  }
}