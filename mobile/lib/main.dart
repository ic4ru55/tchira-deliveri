import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/livraison_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/home_client.dart';
import 'screens/livreur/home_livreur.dart';
import 'screens/receptionniste/home_receptionniste.dart';
import 'screens/admin/home_admin.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LivraisonProvider()),
      ],
      child: const TchiraApp(),
    ),
  );
}

class TchiraApp extends StatelessWidget {
  const TchiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tchira Express',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D7377), // vert teal Tchira
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verifierSession();
  }

  Future<void> _verifierSession() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.restaurerSession();

    if (!mounted) return;

    if (auth.estConnecte) {
      _naviguerVersHome(auth);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

 void _naviguerVersHome(AuthProvider auth) {
  Widget ecran;

  if (auth.estClient) {
    ecran = const HomeClient();
  } else if (auth.estLivreur) {
    ecran = const HomeLibreur();
  } else if (auth.estReceptionniste) {
    ecran = const HomeReceptionniste();
  } else if (auth.estAdmin) {
    ecran = const HomeAdmin();
  } else {
    ecran = const LoginScreen();
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => ecran),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D7377),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ── Logo ────────────────────────────────────────────────
            Container(
              width:  140,
              height: 140,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(70),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset:     const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(70),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Nom ─────────────────────────────────────────────────
            const Text(
              'Tchira Express',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Livraison rapide à Bobo-Dioulasso',
              style: TextStyle(
                color:    Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),

            // ── Spinner ──────────────────────────────────────────────
            const CircularProgressIndicator(
              color:       Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}