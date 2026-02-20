import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/livraison_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/home_client.dart';
import 'screens/livreur/home_livreur.dart';

void main() {
  runApp(
    // MultiProvider — on enregistre tous nos providers ici
    // Ils seront disponibles partout dans l'app
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
      title: 'Tchira Delivery',
      debugShowCheckedModeBanner: false, // retire le bandeau "DEBUG"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // bleu Tchira
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── Écran de démarrage — vérifie si l'user est déjà connecté ────────────────
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
    // Attendre que le widget soit construit avant d'accéder au context
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    // Essayer de restaurer une session existante
    await auth.restaurerSession();

    if (!mounted) return;

    // Rediriger selon l'état
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => auth.estClient
            ? const HomeClient()
            : const HomeLibreur(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1B3A6B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Tchira Delivery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}