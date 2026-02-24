import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class HomeReceptionniste extends StatefulWidget {
  const HomeReceptionniste({super.key});

  @override
  State<HomeReceptionniste> createState() => _HomeReceptionnisteState();
}

class _HomeReceptionnisteState extends State<HomeReceptionniste>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Formulaire nouvelle commande
  final _departCtrl    = TextEditingController();
  final _arriveeCtrl   = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _nomClientCtrl = TextEditingController();
  final _telClientCtrl = TextEditingController();

  bool          _formVisible         = false;
  bool          _chargementTarifs    = true;
  bool          _calculEnCours       = false;
  bool          _surDevis            = false;
  bool          _creationEnCours     = false;

  List<dynamic> _tarifs              = [];
  List<dynamic> _zones               = [];
  List<dynamic> _livraisonsEnCours   = [];
  List<dynamic> _livraisonsAttente   = [];
  List<dynamic> _tousLivreurs        = []; // tous avec statut (pour affichage)

  String?       _categorieSelectionnee;
  String?       _zoneSelectionnee;
  String?       _livreurSelectionne;

  double?       _prixBase;
  double?       _fraisZone;
  double?       _prixTotal;

  bool          _chargementLivraisons = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chargerTarifs();
    _chargerLivraisons();
    _chargerLivreursDisponibles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _departCtrl.dispose();
    _arriveeCtrl.dispose();
    _descCtrl.dispose();
    _nomClientCtrl.dispose();
    _telClientCtrl.dispose();
    super.dispose();
  }

  // ─── Chargements ──────────────────────────────────────────────────────────
  Future<void> _chargerTarifs() async {
    try {
      final reponse = await ApiService.getTarifs();
      if (!mounted) return;
      if (reponse['success'] == true) {
        setState(() {
          _tarifs           = reponse['tarifs'];
          _zones            = reponse['zones'];
          _chargementTarifs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _chargementTarifs = false);
    }
  }

  Future<void> _chargerLivraisons() async {
    setState(() => _chargementLivraisons = true);
    try {
      // 📚 On fait 3 appels en parallèle avec Future.wait
      // Au lieu de les faire l'un après l'autre (3x plus lent)
      // Future.wait attend que TOUS soient terminés avant de continuer
      final resultats = await Future.wait([
        ApiService.toutesLesLivraisons(statut: 'en_attente'),
        ApiService.toutesLesLivraisons(statut: 'en_cours'),
        ApiService.toutesLesLivraisons(statut: 'en_livraison'),
      ]);

      if (!mounted) return;

      setState(() {
        _livraisonsAttente = resultats[0]['livraisons'] ?? [];
        _livraisonsEnCours = [
          ...(resultats[1]['livraisons'] ?? []),
          ...(resultats[2]['livraisons'] ?? []),
        ];
        _chargementLivraisons = false;
      });
    } catch (e) {
      if (mounted) setState(() => _chargementLivraisons = false);
    }
  }

  Future<void> _chargerLivreursDisponibles() async {
    try {
      final reponse = await ApiService.getLivreursDisponibles();
      if (!mounted) return;
      if (reponse['success'] == true) {
        setState(() {
          _tousLivreurs = reponse['tousLivreurs'] ?? reponse['livreurs'] ?? [];
        });
      }
    } catch (e) {
      // silencieux — pas bloquant
    }
  }

  Future<void> _calculerPrix() async {
    if (_categorieSelectionnee == null || _zoneSelectionnee == null) return;

    setState(() => _calculEnCours = true);
    try {
      final reponse = await ApiService.calculerPrix(
        categorie: _categorieSelectionnee!,
        zoneCode:  _zoneSelectionnee!,
      );
      if (!mounted) return;
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
      if (mounted) setState(() => _calculEnCours = false);
    }
  }

  // ─── Création commande ────────────────────────────────────────────────────
  Future<void> _creerCommande() async {
    if (_nomClientCtrl.text.isEmpty || _telClientCtrl.text.isEmpty) {
      _snack('Remplis le nom et le téléphone du client', Colors.red);
      return;
    }
    if (_departCtrl.text.isEmpty || _arriveeCtrl.text.isEmpty) {
      _snack('Remplis les adresses', Colors.red);
      return;
    }
    if (_categorieSelectionnee == null || _zoneSelectionnee == null) {
      _snack('Sélectionne une catégorie et une zone', Colors.red);
      return;
    }
    if (_surDevis) {
      _snack('Contacte l\'admin pour ce type de colis', Colors.orange);
      return;
    }

    setState(() => _creationEnCours = true);

    // ✅ Capturer AVANT tout await — règle fondamentale Flutter async
    // context peut devenir invalide après un await si le widget est détruit
    final provider  = context.read<LivraisonProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
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
        // Assigner le livreur si sélectionné
        if (_livreurSelectionne != null &&
            provider.mesLivraisons.isNotEmpty) {
          final livraisonId = provider.mesLivraisons.first.id;
          await ApiService.assignerLivreur(
            livraisonId: livraisonId,
            livreurId:   _livreurSelectionne!,
          );
        }

        _viderFormulaire();
        messenger.showSnackBar(const SnackBar(
          content:         Text('✅ Commande créée avec succès !'),
          backgroundColor: Colors.green,
        ));
        if (mounted) _chargerLivraisons();
      } else {
        messenger.showSnackBar(const SnackBar(
          content:         Text('❌ Erreur lors de la création'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _creationEnCours = false);
    }
  }

  // ─── Assignation livreur ──────────────────────────────────────────────────
  Future<void> _assignerLivreur(
      String livraisonId, String livreurId) async {
    // ✅ Capturer le messenger AVANT le await
    final messenger = ScaffoldMessenger.of(context);

    try {
      final reponse = await ApiService.assignerLivreur(
        livraisonId: livraisonId,
        livreurId:   livreurId,
      );
      if (!mounted) return;
      if (reponse['success'] == true) {
        messenger.showSnackBar(const SnackBar(
          content:         Text('✅ Livreur assigné !'),
          backgroundColor: Colors.green,
        ));
        _chargerLivraisons();
        _chargerLivreursDisponibles();
      } else {
        messenger.showSnackBar(SnackBar(
          content:         Text(reponse['message'] ?? 'Erreur'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
        content:         Text('Erreur réseau'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ─── Annulation ───────────────────────────────────────────────────────────
  Future<void> _annulerLivraison(String id) async {
    // ✅ Capturer AVANT le await
    final messenger = ScaffoldMessenger.of(context);

    try {
      final reponse = await ApiService.annulerLivraison(id);
      if (!mounted) return;
      if (reponse['success'] == true) {
        messenger.showSnackBar(const SnackBar(
          content:         Text('Livraison annulée'),
          backgroundColor: Colors.orange,
        ));
        _chargerLivraisons();
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
        content:         Text('Erreur réseau'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ─── Déconnexion ──────────────────────────────────────────────────────────
  Future<void> _deconnecter() async {
    // ✅ Capturer authProvider ET navigator AVANT le await
    final auth      = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    await auth.deconnecter();

    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _viderFormulaire() {
    _departCtrl.clear();
    _arriveeCtrl.clear();
    _descCtrl.clear();
    _nomClientCtrl.clear();
    _telClientCtrl.clear();
    setState(() {
      _formVisible           = false;
      _categorieSelectionnee = null;
      _zoneSelectionnee      = null;
      _livreurSelectionne    = null;
      _prixTotal             = null;
      _prixBase              = null;
      _fraisZone             = null;
    });
  }

  // 📚 _snack reste utile pour les appels synchrones (validations)
  // Pour les appels après await, on utilise ScaffoldMessenger capturé avant
  void _snack(String msg, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tchira Express',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Réceptionniste : ${auth.user?.nom ?? ""}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _chargerLivraisons();
              _chargerLivreursDisponibles();
            },
          ),
          IconButton(
            icon:      const Icon(Icons.logout, color: Colors.white),
            onPressed: _deconnecter,
          ),
        ],
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       const Color(0xFFF97316),
          labelColor:           Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Commandes'),
            Tab(icon: Icon(Icons.list_alt),            text: 'En cours'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _ongletCommandes(),
          _ongletEnCours(),
        ],
      ),

      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () =>
                  setState(() => _formVisible = !_formVisible),
              backgroundColor: const Color(0xFFF97316),
              icon: Icon(_formVisible ? Icons.close : Icons.add),
              label: Text(
                  _formVisible ? 'Annuler' : 'Nouvelle commande'),
            )
          : null,
    );
  }

  // ─── Onglet commandes ─────────────────────────────────────────────────────
  Widget _ongletCommandes() {
    return Column(
      children: [
        if (_formVisible)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _carteInfoClient(),
                  const SizedBox(height: 12),
                  _carteAdresses(),
                  const SizedBox(height: 12),
                  _carteCategories(),
                  const SizedBox(height: 12),
                  _carteZones(),
                  const SizedBox(height: 12),
                  if (_prixTotal != null) _cartePrix(),
                  const SizedBox(height: 12),
                  _carteLivreurAssigner(),
                  const SizedBox(height: 16),
                  _boutonCreer(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: _chargementLivraisons
                ? const Center(child: CircularProgressIndicator())
                : _livraisonsAttente.isEmpty
                    ? _etatVide(
                        'Aucune commande en attente',
                        Icons.inbox_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _chargerLivraisons,
                        child: ListView.builder(
                          padding:   const EdgeInsets.all(16),
                          itemCount: _livraisonsAttente.length,
                          itemBuilder: (context, index) =>
                              _carteCommandeAttente(
                                  _livraisonsAttente[index]),
                        ),
                      ),
          ),
      ],
    );
  }

  // ─── Onglet en cours ──────────────────────────────────────────────────────
  Widget _ongletEnCours() {
    if (_chargementLivraisons) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_livraisonsEnCours.isEmpty) {
      return _etatVide(
        'Aucune livraison en cours',
        Icons.delivery_dining,
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerLivraisons,
      child: ListView.builder(
        padding:   const EdgeInsets.all(16),
        itemCount: _livraisonsEnCours.length,
        itemBuilder: (context, index) =>
            _carteCommandeEnCours(_livraisonsEnCours[index]),
      ),
    );
  }

  // ─── Carte info client ────────────────────────────────────────────────────
  Widget _carteInfoClient() {
    return _conteneur(
      titre: '📞 Client (commande par téléphone)',
      child: Column(
        children: [
          _champTexte(
            ctrl:         _nomClientCtrl,
            label:        'Nom du client',
            icone:        Icons.person_outlined,
            couleurIcone: const Color(0xFF0D7377),
          ),
          const SizedBox(height: 12),
          _champTexte(
            ctrl:         _telClientCtrl,
            label:        'Téléphone du client',
            icone:        Icons.phone_outlined,
            couleurIcone: const Color(0xFF0D7377),
            clavier:      TextInputType.phone,
          ),
        ],
      ),
    );
  }

  // ─── Carte adresses ───────────────────────────────────────────────────────
  Widget _carteAdresses() {
    return _conteneur(
      titre: '📍 Adresses',
      child: Column(
        children: [
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
              margin:  const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectionne
                    ? const Color(0xFF0D7377)
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
                        color:      selectionne
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
                      color:      selectionne
                          ? Colors.white70
                          : const Color(0xFF0D7377),
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

          // ✅ Cast sécurisé — évite le crash si le backend renvoie un double
          final frais = (zone['frais_supplementaires'] as num?)
                  ?.toInt() ??
              0;

          return GestureDetector(
            onTap: () {
              setState(() => _zoneSelectionnee = zone['code']);
              _calculerPrix();
            },
            child: Container(
              margin:  const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectionne
                    ? const Color(0xFF0D7377)
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
                            color:      selectionne
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize:   14,
                          ),
                        ),
                        Text(
                          zone['description'],
                          style: TextStyle(
                            color:    selectionne
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
                      color:      selectionne
                          ? Colors.white70
                          : const Color(0xFF0D7377),
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
                'Ce colis nécessite un devis. Contactez l\'admin.',
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
        color:        const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFF0D7377)),
      ),
      child: Column(
        children: [
          _lignePrix('Prix de base',  _prixBase  ?? 0),
          _lignePrix('Frais de zone', _fraisZone ?? 0),
          const Divider(color: Color(0xFF0D7377)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                  color:      Color(0xFF0D7377),
                ),
              ),
              Text(
                '${_formatPrix(_prixTotal ?? 0)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   18,
                  color:      Color(0xFF0D7377),
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
            style: const TextStyle(color: Color(0xFF0D7377)),
          ),
        ],
      ),
    );
  }

  // ─── Carte sélection livreur ──────────────────────────────────────────────
  Widget _carteLivreurAssigner() {
    return _conteneur(
      titre: '🚴 Assigner un livreur (optionnel)',
      child: _tousLivreurs.isEmpty
          ? const Text(
              'Aucun livreur enregistré',
              style: TextStyle(color: Colors.grey),
            )
          : Column(
              children: [
                const Text(
                  'Sélectionne un livreur :',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                // ✅ Afficher TOUS les livreurs avec leur statut
                ..._tousLivreurs.map((livreur) {
                  final disponible  = livreur['disponible'] as bool? ?? true;
                  final selectionne = _livreurSelectionne == livreur['_id'];

                  return GestureDetector(
                    // ✅ Impossible de sélectionner un livreur occupé
                    onTap: disponible
                        ? () => setState(() => _livreurSelectionne = livreur['_id'])
                        : null,
                    child: Container(
                      margin:  const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !disponible
                            ? Colors.grey.shade100
                            : selectionne
                                ? const Color(0xFFF97316)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: !disponible
                            ? Border.all(color: Colors.grey.shade300)
                            : null,
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius:          16,
                          backgroundColor: !disponible
                              ? Colors.grey.shade200
                              : selectionne
                                  ? Colors.white
                                  : const Color(0xFFD1FAE5),
                          child: Icon(
                            Icons.delivery_dining,
                            color: !disponible
                                ? Colors.grey
                                : selectionne
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFF0D7377),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(livreur['nom'] ?? '',
                                style: TextStyle(
                                  color: !disponible
                                      ? Colors.grey
                                      : selectionne ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                )),
                            Text(livreur['telephone'] ?? '',
                                style: TextStyle(
                                  color: !disponible
                                      ? Colors.grey.shade400
                                      : selectionne ? Colors.white70 : Colors.grey,
                                  fontSize: 12,
                                )),
                          ],
                        )),
                        // ✅ Badge statut
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: disponible
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            disponible ? '● Dispo' : '● En mission',
                            style: TextStyle(
                              color:      disponible ? Colors.green : Colors.orange,
                              fontSize:   10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // ─── Bouton créer commande ────────────────────────────────────────────────
  Widget _boutonCreer() {
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _creationEnCours ? null : _creerCommande,
        icon: _creationEnCours
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
          'Créer la commande',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D7377),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ─── Carte commande en attente ────────────────────────────────────────────
  Widget _carteCommandeAttente(Map<String, dynamic> livraison) {
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
                    color:        Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⏳ En attente',
                    style: TextStyle(
                      color:      Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize:   12,
                    ),
                  ),
                ),
                Text(
                  '${_formatPrix(livraison['prix'])} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   15,
                    color:      Color(0xFF0D7377),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _adresseLigne(
              icone:   Icons.trip_origin,
              couleur: Colors.green,
              texte:   livraison['adresse_depart'] ?? '',
            ),
            const SizedBox(height: 4),
            _adresseLigne(
              icone:   Icons.location_on,
              couleur: Colors.red,
              texte:   livraison['adresse_arrivee'] ?? '',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _tousLivreurs.isEmpty
                      ? const Text(
                          'Aucun livreur enregistré',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      : DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          hint: const Text(
                            'Choisir livreur',
                            style: TextStyle(fontSize: 13),
                          ),
                          // ✅ Afficher TOUS les livreurs avec statut dans le dropdown
                          items: _tousLivreurs
                              .map<DropdownMenuItem<String>>(
                                (l) {
                                  final dispo = l['disponible'] as bool? ?? true;
                                  return DropdownMenuItem(
                                    value:   l['_id'],
                                    enabled: dispo, // ✅ désactivé si en mission
                                    child: Row(children: [
                                      Expanded(child: Text(
                                        l['nom'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: dispo ? Colors.black87 : Colors.grey,
                                        ),
                                      )),
                                      Text(
                                        dispo ? '● Dispo' : '● Mission',
                                        style: TextStyle(
                                          fontSize:   10,
                                          fontWeight: FontWeight.w600,
                                          color: dispo ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ]),
                                  );
                                },
                              )
                              .toList(),
                          onChanged: (livreurId) {
                            if (livreurId != null) {
                              _assignerLivreur(livraison['_id'], livreurId);
                            }
                          },
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                  onPressed: () =>
                      _annulerLivraison(livraison['_id']),
                  tooltip: 'Annuler',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Carte commande en cours ──────────────────────────────────────────────
  Widget _carteCommandeEnCours(Map<String, dynamic> livraison) {
    final statut  = livraison['statut'] as String;
    final couleur = statut == 'en_livraison'
        ? Colors.purple
        : const Color(0xFF0D7377);
    final label   = statut == 'en_livraison'
        ? '🚚 En livraison'
        : '🔄 En cours';

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
                  '${_formatPrix(livraison['prix'])} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize:   15,
                    color:      Color(0xFF0D7377),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _adresseLigne(
              icone:   Icons.trip_origin,
              couleur: Colors.green,
              texte:   livraison['adresse_depart'] ?? '',
            ),
            const SizedBox(height: 4),
            _adresseLigne(
              icone:   Icons.location_on,
              couleur: Colors.red,
              texte:   livraison['adresse_arrivee'] ?? '',
            ),
            if (livraison['livreur'] is Map) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.delivery_dining,
                    color: Color(0xFF0D7377),
                    size:  16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (livraison['livreur'] as Map)['nom'] ?? '',
                    style: const TextStyle(
                      color:      Color(0xFF0D7377),
                      fontWeight: FontWeight.w600,
                      fontSize:   13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (livraison['livreur'] as Map)['telephone'] ?? '',
                    style: const TextStyle(
                      color:    Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
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
              color:      Color(0xFF0D7377),
            ),
          ),
          const SizedBox(height: 12),
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
          borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF0D7377), width: 2),
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

  Widget _etatVide(String message, IconData icone) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  String _formatPrix(dynamic montant) {
    if (montant == null) return '0';
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }
}