import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import 'tracking_screen.dart';

class HomeClient extends StatefulWidget {
  const HomeClient({super.key});

  @override
  State<HomeClient> createState() => _HomeClientState();
}

class _HomeClientState extends State<HomeClient> {
  final _departCtrl  = TextEditingController();
  final _arriveeCtrl = TextEditingController();
  final _prixCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  bool  _formVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivraisonProvider>().chargerMesLivraisons();
    });
  }

  @override
  void dispose() {
    _departCtrl.dispose();
    _arriveeCtrl.dispose();
    _prixCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _creerLivraison() async {
    if (_departCtrl.text.isEmpty || _arriveeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remplis les adresses de départ et d\'arrivée'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<LivraisonProvider>();

    final succes = await provider.creerLivraison(
      adresseDepart:  _departCtrl.text.trim(),
      adresseArrivee: _arriveeCtrl.text.trim(),
      prix:           double.tryParse(_prixCtrl.text) ?? 0.0,
      description:    _descCtrl.text.trim(),
    );

    if (!mounted) return;

    if (succes) {
      _departCtrl.clear();
      _arriveeCtrl.clear();
      _prixCtrl.clear();
      _descCtrl.clear();
      setState(() => _formVisible = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Livraison créée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deconnecter() async {
    await context.read<AuthProvider>().deconnecter();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ auth utilisé dans l'AppBar pour afficher le nom
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<LivraisonProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A6B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tchira Delivery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Bonjour, ${auth.user?.nom ?? ""}',
              // ✅ auth.user utilisé ici
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _deconnecter,
          ),
        ],
      ),

      body: Column(
        children: [

          // ── Bannière bleue ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF1B3A6B),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Envoyer un colis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rapide, fiable et suivi en temps réel',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _formVisible = !_formVisible),
                  icon: Icon(
                    _formVisible ? Icons.close : Icons.add,
                    size: 18,
                  ),
                  label: Text(
                    _formVisible ? 'Annuler' : 'Nouvelle livraison',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Formulaire ─────────────────────────────────────────────────────
          if (_formVisible)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    // ✅ withValues() au lieu de withOpacity()
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails de la livraison',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1B3A6B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _champTexte(
                    ctrl:         _departCtrl,
                    label:        'Adresse de départ',
                    icone:        Icons.location_on,
                    couleurIcone: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _champTexte(
                    ctrl:         _arriveeCtrl,
                    label:        'Adresse d\'arrivée',
                    icone:        Icons.location_on,
                    couleurIcone: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _champTexte(
                    ctrl:         _prixCtrl,
                    label:        'Prix (€)',
                    icone:        Icons.euro,
                    couleurIcone: const Color(0xFF2563EB),
                    clavier:      TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _champTexte(
                    ctrl:         _descCtrl,
                    label:        'Description du colis (optionnel)',
                    icone:        Icons.inventory_2_outlined,
                    couleurIcone: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          provider.isLoading ? null : _creerLivraison,
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Envoyer la demande'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Liste livraisons ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Mes livraisons',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B3A6B),
                      ),
                    ),
                  ),

                  if (provider.isLoading && provider.mesLivraisons.isEmpty)
                    const Center(child: CircularProgressIndicator()),

                  if (!provider.isLoading && provider.mesLivraisons.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune livraison pour l\'instant',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.mesLivraisons.length,
                      itemBuilder: (context, index) {
                        return _carteLivraison(
                            provider.mesLivraisons[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteLivraison(Livraison livraison) {
    final couleurStatut = _couleurStatut(livraison.statut);
    final labelStatut   = _labelStatut(livraison.statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleurStatut.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labelStatut,
                    style: TextStyle(
                      color: couleurStatut,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${livraison.prix.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1B3A6B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _adresseLigne(
              icone:   Icons.trip_origin,
              couleur: Colors.green,
              texte:   livraison.adresseDepart,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: SizedBox(
                height: 16,
                child: VerticalDivider(color: Colors.grey, thickness: 1),
              ),
            ),
            _adresseLigne(
              icone:   Icons.location_on,
              couleur: Colors.red,
              texte:   livraison.adresseArrivee,
            ),

            if (livraison.statut == 'en_cours' ||
                livraison.statut == 'en_livraison') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context
                        .read<LivraisonProvider>()
                        .suivreLivraison(livraison);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TrackingScreen()),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Suivre le livreur'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _adresseLigne({
    required IconData icone,
    required Color couleur,
    required String texte,
  }) {
    return Row(
      children: [
        Icon(icone, color: couleur, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texte,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _champTexte({
    required TextEditingController ctrl,
    required String label,
    required IconData icone,
    required Color couleurIcone,
    TextInputType clavier = TextInputType.text,
  }) {
    return TextField(
      controller:   ctrl,
      keyboardType: clavier,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icone, color: couleurIcone, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        filled:         true,
        fillColor:      const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
      ),
    );
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return Colors.orange;
      case 'en_cours':     return const Color(0xFF2563EB);
      case 'en_livraison': return Colors.purple;
      case 'livre':        return Colors.green;
      case 'annule':       return Colors.red;
      default:             return Colors.grey;
    }
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'en_attente':   return '⏳ En attente';
      case 'en_cours':     return '🔄 En cours';
      case 'en_livraison': return '🚚 En livraison';
      case 'livre':        return '✅ Livré';
      case 'annule':       return '❌ Annulé';
      default:             return statut;
    }
  }
}