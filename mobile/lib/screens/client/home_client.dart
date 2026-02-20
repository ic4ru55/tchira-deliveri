import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../models/livraison.dart';
import '../../screens/auth/login_screen.dart';
import '../../services/api_service.dart';
import 'tracking_screen.dart';

class HomeClient extends StatefulWidget {
  const HomeClient({super.key});

  @override
  State<HomeClient> createState() => _HomeClientState();
}

class _HomeClientState extends State<HomeClient> {
  final _departCtrl  = TextEditingController();
  final _arriveeCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();

  bool          _formVisible           = false;
  bool          _chargementTarifs      = true;
  bool          _gpsEnCours            = false;
  bool          _calculEnCours         = false;
  bool          _surDevis              = false;

  List<dynamic> _tarifs                = [];
  List<dynamic> _zones                 = [];

  String?       _categorieSelectionnee;
  String?       _zoneSelectionnee;

  double?       _prixBase;
  double?       _fraisZone;
  double?       _prixTotal;

  @override
  void initState() {
    super.initState();
    _chargerTarifs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivraisonProvider>().chargerMesLivraisons();
    });
  }

  @override
  void dispose() {
    _departCtrl.dispose();
    _arriveeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─── Charger tarifs ───────────────────────────────────────────────────────
  Future<void> _chargerTarifs() async {
    try {
      final reponse = await ApiService.getTarifs();
      if (reponse['success'] == true) {
        setState(() {
          _tarifs           = reponse['tarifs'];
          _zones            = reponse['zones'];
          _chargementTarifs = false;
        });
      }
    } catch (e) {
      setState(() => _chargementTarifs = false);
    }
  }

  // ─── Calculer le prix ─────────────────────────────────────────────────────
  Future<void> _calculerPrix() async {
    if (_categorieSelectionnee == null || _zoneSelectionnee == null) return;

    setState(() => _calculEnCours = true);

    try {
      final reponse = await ApiService.calculerPrix(
        categorie: _categorieSelectionnee!,
        zoneCode:  _zoneSelectionnee!,
      );

      if (reponse['success'] == true) {
        setState(() {
          _surDevis  = reponse['sur_devis'] ?? false;
          _prixBase  = (reponse['prix_base']  ?? 0).toDouble();
          _fraisZone = (reponse['frais_zone'] ?? 0).toDouble();
          _prixTotal = (reponse['prix_total'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      // silencieux
    } finally {
      setState(() => _calculEnCours = false);
    }
  }

  // ─── Récupérer position GPS ───────────────────────────────────────────────
  Future<void> _recupererPositionGPS() async {
    setState(() => _gpsEnCours = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack('Permission GPS refusée', Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _snack('GPS bloqué — active-le dans les paramètres', Colors.red);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Sur Chrome → afficher les coordonnées directement
      if (kIsWeb) {
        final adresse =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
        setState(() => _departCtrl.text = adresse);
        _snack('✅ Coordonnées récupérées !', Colors.green);
        return;
      }

      // Sur mobile → convertir en adresse lisible
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place   = placemarks.first;
        final adresse = [
          place.street,
          place.subLocality,
          place.locality,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() => _departCtrl.text = adresse);
        _snack('✅ Position récupérée !', Colors.green);
      } else {
        setState(() => _departCtrl.text =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}');
        _snack('✅ Position récupérée !', Colors.green);
      }

    } catch (e) {
      _snack('Impossible de récupérer la position', Colors.red);
    } finally {
      setState(() => _gpsEnCours = false);
    }
  }

  // ─── Créer la livraison ───────────────────────────────────────────────────
  Future<void> _creerLivraison() async {
    if (_departCtrl.text.isEmpty || _arriveeCtrl.text.isEmpty) {
      _snack('Remplis les adresses de départ et d\'arrivée', Colors.red);
      return;
    }
    if (_categorieSelectionnee == null) {
      _snack('Sélectionne une catégorie de colis', Colors.red);
      return;
    }
    if (_zoneSelectionnee == null) {
      _snack('Sélectionne une zone de livraison', Colors.red);
      return;
    }
    if (_surDevis) {
      _snack('Contacte l\'administrateur pour ce type de colis',
          Colors.orange);
      return;
    }

    final provider = context.read<LivraisonProvider>();

    final succes = await provider.creerLivraison(
      adresseDepart:  _departCtrl.text.trim(),
      adresseArrivee: _arriveeCtrl.text.trim(),
      categorie:      _categorieSelectionnee!,
      zoneCode:       _zoneSelectionnee!,
      prix:           _prixTotal  ?? 0,
      prixBase:       _prixBase   ?? 0,
      fraisZone:      _fraisZone  ?? 0,
      description:    _descCtrl.text.trim(),
    );

    if (!mounted) return;

    if (succes) {
      _departCtrl.clear();
      _arriveeCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _formVisible           = false;
        _categorieSelectionnee = null;
        _zoneSelectionnee      = null;
        _prixTotal             = null;
        _prixBase              = null;
        _fraisZone             = null;
      });
      _snack('✅ Livraison créée avec succès !', Colors.green);
    } else {
      _snack('❌ Erreur lors de la création', Colors.red);
    }
  }

  // ─── Déconnecter ─────────────────────────────────────────────────────────
  Future<void> _deconnecter() async {
    await context.read<AuthProvider>().deconnecter();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _snack(String msg, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
                color:      Colors.white,
                fontSize:   16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Bonjour, ${auth.user?.nom ?? ""}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:      const Icon(Icons.logout, color: Colors.white),
            onPressed: _deconnecter,
          ),
        ],
      ),

      body: Column(
        children: [

          // ── Bannière ────────────────────────────────────────────────────
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
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bobo-Dioulasso & environs',
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

          // ── Formulaire ──────────────────────────────────────────────────
          if (_formVisible)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _carteFormulaire(),
                    const SizedBox(height: 12),
                    _carteCategories(),
                    const SizedBox(height: 12),
                    _carteZones(),
                    const SizedBox(height: 12),
                    if (_prixTotal != null) _cartePrix(),
                    const SizedBox(height: 16),
                    _boutonCreer(provider),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

          // ── Liste livraisons ────────────────────────────────────────────
          if (!_formVisible)
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
                          fontSize:   16,
                          fontWeight: FontWeight.bold,
                          color:      Color(0xFF1B3A6B),
                        ),
                      ),
                    ),
                    if (provider.isLoading &&
                        provider.mesLivraisons.isEmpty)
                      const Center(child: CircularProgressIndicator()),
                    if (!provider.isLoading &&
                        provider.mesLivraisons.isEmpty)
                      _etatVide(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: provider.mesLivraisons.length,
                        itemBuilder: (context, index) =>
                            _carteLivraison(
                                provider.mesLivraisons[index]),
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

  // ─── Carte adresses + bouton GPS ─────────────────────────────────────────
  Widget _carteFormulaire() {
    return _conteneur(
      titre: '📍 Adresses',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _champTexte(
                  ctrl:         _departCtrl,
                  label:        'Adresse de départ',
                  icone:        Icons.location_on,
                  couleurIcone: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 54,
                width:  54,
                decoration: BoxDecoration(
                  color:        const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _gpsEnCours
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          color:       Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size:  22,
                        ),
                        onPressed: _recupererPositionGPS,
                        tooltip: 'Utiliser ma position actuelle',
                      ),
              ),
            ],
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
            ctrl:         _descCtrl,
            label:        'Description du colis (optionnel)',
            icone:        Icons.inventory_2_outlined,
            couleurIcone: Colors.grey,
          ),
        ],
      ),
    );
  }

  // ─── Carte catégories ─────────────────────────────────────────────────────
  Widget _carteCategories() {
    if (_chargementTarifs) {
      return const Center(child: CircularProgressIndicator());
    }

    return _conteneur(
      titre: '📦 Catégorie du colis',
      child: Column(
        children: _tarifs.map((tarif) {
          final selectionne = _categorieSelectionnee == tarif['categorie'];
          final surDevis    = tarif['sur_devis'] == true;

          return GestureDetector(
            onTap: () {
              setState(
                  () => _categorieSelectionnee = tarif['categorie']);
              _calculerPrix();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectionne
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: selectionne ? Colors.white : Colors.grey,
                    size:  20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tarif['label'],
                      style: TextStyle(
                        color: selectionne
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize:   14,
                      ),
                    ),
                  ),
                  Text(
                    surDevis
                        ? 'Sur devis'
                        : '${_formatPrix(tarif['prix_base'])} FCFA',
                    style: TextStyle(
                      color: selectionne
                          ? Colors.white70
                          : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize:   13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Carte zones ──────────────────────────────────────────────────────────
  Widget _carteZones() {
    if (_chargementTarifs) return const SizedBox.shrink();

    return _conteneur(
      titre: '🗺️ Zone de livraison',
      child: Column(
        children: _zones.map((zone) {
          final selectionne = _zoneSelectionnee == zone['code'];
          final frais       = zone['frais_supplementaires'] as int;

          return GestureDetector(
            onTap: () {
              setState(() => _zoneSelectionnee = zone['code']);
              _calculerPrix();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectionne
                    ? const Color(0xFF1B3A6B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: selectionne ? Colors.white : Colors.grey,
                    size:  20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['nom'],
                          style: TextStyle(
                            color: selectionne
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize:   14,
                          ),
                        ),
                        Text(
                          zone['description'],
                          style: TextStyle(
                            color: selectionne
                                ? Colors.white60
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    frais == 0
                        ? 'Inclus'
                        : '+${_formatPrix(frais)} FCFA',
                    style: TextStyle(
                      color: selectionne
                          ? Colors.white70
                          : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize:   13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Carte récap prix ─────────────────────────────────────────────────────
  Widget _cartePrix() {
    if (_calculEnCours) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_surDevis) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        const Color(0xFFFEF9C3),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ce type de colis nécessite un devis.\nContactez l\'administrateur.',
                style: TextStyle(color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFF2563EB)),
      ),
      child: Column(
        children: [
          _lignePrix('Prix de base',  _prixBase  ?? 0),
          _lignePrix('Frais de zone', _fraisZone ?? 0),
          const Divider(color: Color(0xFF2563EB)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                  color:      Color(0xFF1B3A6B),
                ),
              ),
              Text(
                '${_formatPrix(_prixTotal ?? 0)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   18,
                  color:      Color(0xFF1B3A6B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lignePrix(String label, double montant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            '${_formatPrix(montant)} FCFA',
            style: const TextStyle(color: Color(0xFF1B3A6B)),
          ),
        ],
      ),
    );
  }

  // ─── Bouton créer ─────────────────────────────────────────────────────────
  Widget _boutonCreer(LivraisonProvider provider) {
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: provider.isLoading ? null : _creerLivraison,
        icon: provider.isLoading
            ? const SizedBox(
                width:  20,
                height: 20,
                child:  CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send),
        label: const Text(
          'Envoyer la demande',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ─── Carte livraison ──────────────────────────────────────────────────────
  Widget _carteLivraison(Livraison livraison) {
    final couleur = _couleurStatut(livraison.statut);
    final label   = _labelStatut(livraison.statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
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
                    color:        couleur.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color:      couleur,
                      fontWeight: FontWeight.w600,
                      fontSize:   12,
                    ),
                  ),
                ),
                Text(
                  '${_formatPrix(livraison.prix)} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   16,
                    color:      Color(0xFF1B3A6B),
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
                child:  VerticalDivider(
                    color: Colors.grey, thickness: 1),
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
                  icon:  const Icon(Icons.map_outlined, size: 16),
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

  // ─── Widgets utilitaires ──────────────────────────────────────────────────
  Widget _conteneur({required String titre, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize:   15,
              color:      Color(0xFF1B3A6B),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _champTexte({
    required TextEditingController ctrl,
    required String                label,
    required IconData              icone,
    required Color                 couleurIcone,
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

  Widget _adresseLigne({
    required IconData icone,
    required Color    couleur,
    required String   texte,
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

  Widget _etatVide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.inbox_outlined,
            size:  64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune livraison pour l\'instant',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _formatPrix(dynamic montant) {
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
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