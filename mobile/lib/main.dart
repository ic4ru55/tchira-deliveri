import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/livraison_provider.dart';
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
      ],
      child: MaterialApp(
        title:                      'Tchira Express',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D7377)),
          useMaterial3: true,
        ),
        home: const SplashDecision(),
      ),
    );
  }
}

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
    // ✅ Capturer TOUT ce qui vient de context AVANT le premier await
    final prefs    = await SharedPreferences.getInstance();
    // ignore: use_build_context_synchronously
    if (!mounted) return;
    final auth     = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    // ── Onboarding jamais vu ──
    final onboardingVu = prefs.getBool('onboarding_vu') ?? false;
    if (!onboardingVu) {
      if (!mounted) return;
      navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    // ── Restaurer la session ──
    await auth.restaurerSession();
    if (!mounted) return;

    if (!auth.estConnecte) {
      navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // ── Rediriger selon le rôle ──
    Widget ecran;
    switch (auth.user?.role) {
      case 'admin':
        ecran = const HomeAdmin();
        break;
      case 'livreur':
        ecran = const HomeLibreur();
        break;
      case 'receptionniste':
        ecran = const HomeReceptionniste();
        break;
      default:
        ecran = const HomeClient();
    }

    if (!mounted) return;
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => ecran));
  }

  @override
  Widget build(BuildContext context) {
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
                  color:      Colors.white,
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                )),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white70),
          ],
        ),
      ),
    );
  }
}