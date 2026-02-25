import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _pageCourante = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final List<_PageOnboarding> _pages = [
    _PageOnboarding(
      emoji:       '🚀',
      titre:       'Bienvenue sur\nTchira Express',
      description: 'La solution de livraison rapide et fiable\nà Bobo-Dioulasso et ses environs.',
      couleurFond: const Color(0xFF0D7377),
      couleurAccent: const Color(0xFF0FA3A8),
    ),
    _PageOnboarding(
      emoji:       '📦',
      titre:       'Envoyez vos colis\nen quelques clics',
      description: 'Choisissez votre départ, destination et\ncatégorie de colis. On s\'occupe du reste.',
      couleurFond: const Color(0xFF1B3A6B),
      couleurAccent: const Color(0xFF2A5298),
    ),
    _PageOnboarding(
      emoji:       '📍',
      titre:       'Suivez vos livraisons\nen temps réel',
      description: 'Tracking GPS en direct, notifications\ninstantanées à chaque étape.',
      couleurFond: const Color(0xFFF97316),
      couleurAccent: const Color(0xFFFF8C42),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_vu', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _pageSuivante() {
    if (_pageCourante < _pages.length - 1) {
      _animCtrl.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve:    Curves.easeInOut,
      );
      _animCtrl.forward();
    } else {
      _terminer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_pageCourante];
    final estDerniere = _pageCourante == _pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [page.couleurFond, page.couleurAccent],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // Bouton Passer
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: estDerniere
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: _terminer,
                        child: const Text(
                          'Passer',
                          style: TextStyle(
                            color:      Colors.white70,
                            fontSize:   14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ),

            // Contenu
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) {
                  setState(() => _pageCourante = i);
                  _animCtrl.reset();
                  _animCtrl.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageContent(
                  page:     _pages[i],
                  fadeAnim: _fadeAnim,
                ),
              ),
            ),

            // Points + bouton
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(children: [
                // Points indicateurs
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width:  _pageCourante == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _pageCourante == i
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Bouton Suivant / Commencer
                SizedBox(
                  width:  double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _pageSuivante,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: page.couleurFond,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      estDerniere ? 'Commencer 🚀' : 'Suivant',
                      style: const TextStyle(
                        fontSize:   17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _PageOnboarding page;
  final Animation<double> fadeAnim;
  const _PageContent({required this.page, required this.fadeAnim});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji dans un cercle
            Container(
              width:  140,
              height: 140,
              decoration: BoxDecoration(
                color:  Colors.white.withValues(alpha: 0.15),
                shape:  BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  page.emoji,
                  style: const TextStyle(fontSize: 64),
                ),
              ),
            ),
            const SizedBox(height: 40),

            Text(
              page.titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   26,
                fontWeight: FontWeight.bold,
                height:     1.3,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              page.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:    Colors.white70,
                fontSize: 15,
                height:   1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageOnboarding {
  final String emoji;
  final String titre;
  final String description;
  final Color  couleurFond;
  final Color  couleurAccent;
  const _PageOnboarding({
    required this.emoji,
    required this.titre,
    required this.description,
    required this.couleurFond,
    required this.couleurAccent,
  });
}