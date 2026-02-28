import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livraison_provider.dart';
import '../../services/api_service.dart';
import '../../screens/auth/login_screen.dart';
import '../profil_page.dart';
import '../validation_paiement_screen.dart';

class HomeReceptionniste extends StatefulWidget {
  const HomeReceptionniste({super.key});
  @override
  State<HomeReceptionniste> createState() => _HomeReceptionnisteState();
}

class _HomeReceptionnisteState extends State<HomeReceptionniste> {
  int _ongletActif = 0; // 0=Commandes 1=En cours 2=Paiements 3=Profil
  final int _nbPreuves   = 0;  // badge sur onglet Paiements

  final _departCtrl    = TextEditingController();
  final _arriveeCtrl   = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _nomClientCtrl = TextEditingController();
  final _telClientCtrl = TextEditingController();

  bool   _formVisible         = false;
  bool   _chargementTarifs    = true;
  bool   _calculEnCours       = false;
  bool   _surDevis            = false;
  bool   _creationEnCours     = false;
  bool   _chargementLivraisons = true;

  List<dynamic> _tarifs              = [];
  List<dynamic> _zones               = [];
  List<dynamic> _livraisonsEnCours   = [];
  List<dynamic> _livraisonsAttente   = [];
  List<dynamic> _livreursDisponibles = [];

  String? _categorieSelectionnee;
  String? _zoneSelectionnee;
  String? _livreurSelectionne;
  double? _prixBase;
  double? _fraisZone;
  double? _prixTotal;

  @override
  void initState() { super.initState(); _chargerTarifs(); _chargerLivraisons(); _chargerLivreursDisponibles(); }

  @override
  void dispose() { _departCtrl.dispose(); _arriveeCtrl.dispose(); _descCtrl.dispose(); _nomClientCtrl.dispose(); _telClientCtrl.dispose(); super.dispose(); }

  Future<void> _chargerTarifs() async {
    try { final r = await ApiService.getTarifs(); if (!mounted) return;
      if (r['success'] == true) setState(() { _tarifs = r['tarifs']; _zones = r['zones']; _chargementTarifs = false; }); }
    catch (_) { if (mounted) setState(() => _chargementTarifs = false); }
  }

  Future<void> _chargerLivraisons() async {
    setState(() => _chargementLivraisons = true);
    try {
      final res = await Future.wait([ApiService.toutesLesLivraisons(statut: 'en_attente'), ApiService.toutesLesLivraisons(statut: 'en_cours'), ApiService.toutesLesLivraisons(statut: 'en_livraison')]);
      if (!mounted) return;
      setState(() { _livraisonsAttente = res[0]['livraisons'] ?? []; _livraisonsEnCours = [...(res[1]['livraisons'] ?? []), ...(res[2]['livraisons'] ?? [])]; _chargementLivraisons = false; });
    } catch (_) { if (mounted) setState(() => _chargementLivraisons = false); }
  }

  Future<void> _chargerLivreursDisponibles() async {
    try { final r = await ApiService.getLivreursDisponibles(); if (!mounted) return; if (r['success'] == true) setState(() => _livreursDisponibles = r['livreurs']); } catch (_) {}
  }

  Future<void> _calculerPrix() async {
    if (_categorieSelectionnee == null || _zoneSelectionnee == null) return;
    setState(() => _calculEnCours = true);
    try { final r = await ApiService.calculerPrix(categorie: _categorieSelectionnee!, zoneCode: _zoneSelectionnee!);
      if (!mounted) return;
      if (r['success'] == true) setState(() { _surDevis = r['sur_devis'] ?? false; _prixBase = (r['prix_base'] ?? 0).toDouble(); _fraisZone = (r['frais_zone'] ?? 0).toDouble(); _prixTotal = (r['prix_total'] ?? 0).toDouble(); });
    } finally { if (mounted) setState(() => _calculEnCours = false); }
  }

  Future<void> _creerCommande() async {
    if (_nomClientCtrl.text.isEmpty || _telClientCtrl.text.isEmpty) { _snack('Remplis le nom et le téléphone du client', Colors.red); return; }
    if (_departCtrl.text.isEmpty || _arriveeCtrl.text.isEmpty) { _snack('Remplis les adresses', Colors.red); return; }
    if (_categorieSelectionnee == null || _zoneSelectionnee == null) { _snack('Sélectionne une catégorie et une zone', Colors.red); return; }
    if (_surDevis) { _snack('Contacte l\'admin pour ce type de colis', Colors.orange); return; }
    setState(() => _creationEnCours = true);
    final provider = context.read<LivraisonProvider>(); final messenger = ScaffoldMessenger.of(context);
    try {
      final String? livraisonId = await provider.creerLivraison(adresseDepart: _departCtrl.text.trim(), adresseArrivee: _arriveeCtrl.text.trim(), categorie: _categorieSelectionnee!, zoneCode: _zoneSelectionnee!, prix: _prixTotal ?? 0, prixBase: _prixBase ?? 0, fraisZone: _fraisZone ?? 0, description: _descCtrl.text.trim());
      if (!mounted) return;
      if (livraisonId != null) {
        if (_livreurSelectionne != null) await ApiService.assignerLivreur(livraisonId: livraisonId, livreurId: _livreurSelectionne!);
        _viderFormulaire(); messenger.showSnackBar(const SnackBar(content: Text('✅ Commande créée !'), backgroundColor: Colors.green));
        setState(() => _ongletActif = 1); if (mounted) _chargerLivraisons();
      } else messenger.showSnackBar(const SnackBar(content: Text('❌ Erreur lors de la création'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _creationEnCours = false); }
  }

  Future<void> _assignerLivreur(String livId, String livreurId) async {
    final messenger = ScaffoldMessenger.of(context);
    try { final r = await ApiService.assignerLivreur(livraisonId: livId, livreurId: livreurId);
      if (!mounted) return;
      if (r['success'] == true) { messenger.showSnackBar(const SnackBar(content: Text('✅ Livreur assigné !'), backgroundColor: Colors.green)); _chargerLivraisons(); _chargerLivreursDisponibles(); }
      else messenger.showSnackBar(SnackBar(content: Text(r['message'] ?? 'Erreur'), backgroundColor: Colors.red));
    } catch (_) { messenger.showSnackBar(const SnackBar(content: Text('Erreur réseau'), backgroundColor: Colors.red)); }
  }

  Future<void> _annulerLivraison(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try { final r = await ApiService.annulerLivraison(id);
      if (!mounted) return;
      if (r['success'] == true) { messenger.showSnackBar(const SnackBar(content: Text('Livraison annulée'), backgroundColor: Colors.orange)); _chargerLivraisons(); }
    } catch (_) { messenger.showSnackBar(const SnackBar(content: Text('Erreur réseau'), backgroundColor: Colors.red)); }
  }

  void _viderFormulaire() { _departCtrl.clear(); _arriveeCtrl.clear(); _descCtrl.clear(); _nomClientCtrl.clear(); _telClientCtrl.clear(); setState(() { _formVisible = false; _categorieSelectionnee = null; _zoneSelectionnee = null; _livreurSelectionne = null; _prixTotal = null; _prixBase = null; _fraisZone = null; }); }
  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pages = [_pageCommandes(), _pageEnCours(), const ValidationPaiementScreen(), ProfilPage(
          role: 'receptionniste',
          couleurRole: const Color(0xFF0D7377),
          onDeconnexion: () async {
            final nav = Navigator.of(context);
            await auth.deconnecter();
            if (!mounted) return;
            nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
        )];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_ongletActif != 0) {
          setState(() => _ongletActif = 0);
          return;
        }
        final quitter = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Quitter Tchira ?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text("Voulez-vous vraiment quitter l'application ?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
        if (quitter == true) {
          // ✅ SystemNavigator.pop() quitte proprement l'app Android sans écran noir
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: pages[_ongletActif],
      bottomNavigationBar: _navbar(),
      floatingActionButton: _ongletActif == 0
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _formVisible = !_formVisible),
              backgroundColor: const Color(0xFFF97316),
              icon: Icon(_formVisible ? Icons.close : Icons.add),
              label: Text(_formVisible ? 'Annuler' : 'Nouvelle commande'))
          : null,
    ),
    );
  }

  Widget _navbar() {
    final items = [
      {'icon': Icons.add_circle_outline, 'iconSel': Icons.add_circle,  'label': 'Commandes',  'badge': 0},
      {'icon': Icons.list_alt_outlined,  'iconSel': Icons.list_alt,    'label': 'En cours',   'badge': 0},
      {'icon': Icons.verified_outlined,  'iconSel': Icons.verified,    'label': 'Paiements',  'badge': _nbPreuves},
      {'icon': Icons.person_outline,     'iconSel': Icons.person,      'label': 'Profil',     'badge': 0},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Indicateur scrollable ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width:  _ongletActif == i ? 20 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: _ongletActif == i
                    ? const Color(0xFF0D7377) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))))),
        ),
        // ── Onglets ───────────────────────────────────────────────────────────
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final sel   = _ongletActif == i;
              final badge = items[i]['badge'] as int? ?? 0;
              return GestureDetector(
                onTap: () => setState(() => _ongletActif = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF0D7377) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: sel ? null : Border.all(color: Colors.grey.shade200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(
                        sel ? items[i]['iconSel'] as IconData
                            : items[i]['icon'] as IconData,
                        color: sel ? Colors.white : Colors.grey.shade600,
                        size: 18),
                      if (badge > 0)
                        Positioned(right: -6, top: -4,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: Center(child: Text('$badge',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 8, fontWeight: FontWeight.bold))))),
                    ]),
                    const SizedBox(width: 6),
                    Text(items[i]['label'] as String,
                        style: TextStyle(fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? Colors.white : Colors.grey.shade600)),
                  ]),
                ),
              );
            },
          ),
        ),
      ])),
    );
  }

  Widget _pageCommandes() {
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
          decoration: const BoxDecoration(color: Color(0xFF0D7377), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Commandes en attente', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _chargerLivraisons),
          ])),
      if (_formVisible)
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          _carteInfoClient(), const SizedBox(height: 12), _carteAdresses(), const SizedBox(height: 12),
          _carteCategories(), const SizedBox(height: 12), _carteZones(), const SizedBox(height: 12),
          if (_prixTotal != null) _cartePrix(), const SizedBox(height: 12), _carteLivreurAssigner(),
          const SizedBox(height: 16), _boutonCreer(), const SizedBox(height: 80),
        ])))
      else
        Expanded(child: _chargementLivraisons ? const Center(child: CircularProgressIndicator())
            : _livraisonsAttente.isEmpty
                ? _etatVide('Aucune commande en attente', Icons.inbox_outlined)
                : RefreshIndicator(onRefresh: _chargerLivraisons, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _livraisonsAttente.length, itemBuilder: (_, i) => _carteCommandeAttente(_livraisonsAttente[i])))),
    ]);
  }

  Widget _pageEnCours() {
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
          decoration: const BoxDecoration(color: Color(0xFF0D7377), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('En cours (${_livraisonsEnCours.length})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _chargerLivraisons),
          ])),
      Expanded(child: _chargementLivraisons ? const Center(child: CircularProgressIndicator())
          : _livraisonsEnCours.isEmpty ? _etatVide('Aucune livraison en cours', Icons.delivery_dining)
              : RefreshIndicator(onRefresh: _chargerLivraisons, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _livraisonsEnCours.length, itemBuilder: (_, i) => _carteCommandeEnCours(_livraisonsEnCours[i])))),
    ]);
  }

  // ─── Formulaire widgets (inchangés de l'original) ─────────────────────────
  Widget _carteInfoClient() => _conteneur(titre: '📞 Client (commande par téléphone)', child: Column(children: [
    _champ(_nomClientCtrl, 'Nom du client', Icons.person_outlined, const Color(0xFF0D7377)), const SizedBox(height: 12),
    _champ(_telClientCtrl, 'Téléphone du client', Icons.phone_outlined, const Color(0xFF0D7377), clavier: TextInputType.phone),
  ]));

  Widget _carteAdresses() => _conteneur(titre: '📍 Adresses', child: Column(children: [
    _champ(_departCtrl, 'Adresse de départ', Icons.location_on, Colors.green), const SizedBox(height: 12),
    _champ(_arriveeCtrl, 'Adresse d\'arrivée', Icons.location_on, Colors.red), const SizedBox(height: 12),
    _champ(_descCtrl, 'Description du colis (optionnel)', Icons.inventory_2_outlined, Colors.grey),
  ]));

  Widget _carteCategories() {
    if (_chargementTarifs) return const Center(child: CircularProgressIndicator());
    return _conteneur(titre: '📦 Catégorie du colis', child: Column(children: _tarifs.map((tarif) {
      final sel = _categorieSelectionnee == tarif['categorie'];
      return GestureDetector(onTap: () { setState(() => _categorieSelectionnee = tarif['categorie']); _calculerPrix(); },
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: sel ? const Color(0xFF0D7377) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [Icon(Icons.inventory_2, color: sel ? Colors.white : Colors.grey, size: 20), const SizedBox(width: 12),
            Expanded(child: Text(tarif['label'], style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14))),
            Text(tarif['sur_devis'] == true ? 'Sur devis' : '${_fmt(tarif['prix_base'])} FCFA',
                style: TextStyle(color: sel ? Colors.white70 : const Color(0xFF0D7377), fontWeight: FontWeight.bold, fontSize: 13))])));
    }).toList()));
  }

  Widget _carteZones() {
    if (_chargementTarifs) return const SizedBox.shrink();
    return _conteneur(titre: '🗺️ Zone de livraison', child: Column(children: _zones.map((zone) {
      final sel = _zoneSelectionnee == zone['code']; final frais = (zone['frais_supplementaires'] as num?)?.toInt() ?? 0;
      return GestureDetector(onTap: () { setState(() => _zoneSelectionnee = zone['code']); _calculerPrix(); },
        child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: sel ? const Color(0xFF0D7377) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [Icon(Icons.map_outlined, color: sel ? Colors.white : Colors.grey, size: 20), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(zone['nom'], style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(zone['description'], style: TextStyle(color: sel ? Colors.white60 : Colors.grey, fontSize: 12))])),
            Text(frais == 0 ? 'Inclus' : '+${_fmt(frais)} FCFA', style: TextStyle(color: sel ? Colors.white70 : const Color(0xFF0D7377), fontWeight: FontWeight.bold, fontSize: 13))])));
    }).toList()));
  }

  Widget _cartePrix() {
    if (_calculEnCours) return const Center(child: CircularProgressIndicator());
    if (_surDevis) return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B))),
        child: const Row(children: [Icon(Icons.info_outline, color: Color(0xFFF59E0B)), SizedBox(width: 10), Expanded(child: Text('Ce colis nécessite un devis. Contactez l\'admin.', style: TextStyle(color: Color(0xFF92400E))))]));
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0D7377))),
        child: Column(children: [
          _lignePrix('Prix de base', _prixBase ?? 0), _lignePrix('Frais de zone', _fraisZone ?? 0),
          const Divider(color: Color(0xFF0D7377)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D7377))), Text('${_fmt(_prixTotal ?? 0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D7377)))])]));
  }

  Widget _lignePrix(String l, double m) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text('${_fmt(m)} FCFA', style: const TextStyle(color: Color(0xFF0D7377)))]));

  Widget _carteLivreurAssigner() => _conteneur(titre: '🚴 Assigner un livreur (optionnel)', child: _livreursDisponibles.isEmpty
      ? const Text('Aucun livreur disponible', style: TextStyle(color: Colors.grey))
      : Column(children: _livreursDisponibles.map((l) {
          final sel = _livreurSelectionne == l['_id'];
          return GestureDetector(onTap: () => setState(() => _livreurSelectionne = l['_id']),
            child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: sel ? const Color(0xFFF97316) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [CircleAvatar(radius: 16, backgroundColor: sel ? Colors.white : const Color(0xFFD1FAE5), child: Icon(Icons.delivery_dining, color: sel ? const Color(0xFFF97316) : const Color(0xFF0D7377), size: 18)),
                const SizedBox(width: 10), Expanded(child: Text(l['nom'], style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600))),
                Text(l['telephone'] ?? '', style: TextStyle(color: sel ? Colors.white70 : Colors.grey, fontSize: 12))])));
        }).toList()));

  Widget _boutonCreer() => SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
    onPressed: _creationEnCours ? null : _creerCommande,
    icon: _creationEnCours ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
    label: const Text('Créer la commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));

  Widget _carteCommandeAttente(Map<String, dynamic> liv) => Container(margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: const Text('⏳ En attente', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12))),
        Text('${_fmt(liv['prix'])} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377)))]),
      const SizedBox(height: 10),
      Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv['adresse_depart'] ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
      const SizedBox(height: 4),
      Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv['adresse_arrivee'] ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _livreursDisponibles.isEmpty ? const Text('Aucun livreur', style: TextStyle(color: Colors.grey, fontSize: 12))
            : DropdownButtonFormField<String>(decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), hint: const Text('Choisir livreur', style: TextStyle(fontSize: 13)),
                items: _livreursDisponibles.map<DropdownMenuItem<String>>((l) => DropdownMenuItem(value: l['_id'], child: Text(l['nom'], style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (id) { if (id != null) _assignerLivreur(liv['_id'], id); })),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red), onPressed: () => _annulerLivraison(liv['_id'])),
      ]),
    ])));

  Widget _carteCommandeEnCours(Map<String, dynamic> liv) {
    final statut = liv['statut'] as String; final c = statut == 'en_livraison' ? Colors.purple : const Color(0xFF0D7377); final l = statut == 'en_livraison' ? '🚚 En livraison' : '🔄 En cours';
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text(l, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12))),
          Text('${_fmt(liv['prix'])} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377)))]),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv['adresse_depart'] ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(liv['adresse_arrivee'] ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]),
        if (liv['livreur'] is Map) ...[const SizedBox(height: 10), Row(children: [const Icon(Icons.delivery_dining, color: Color(0xFF0D7377), size: 16), const SizedBox(width: 6), Text((liv['livreur'] as Map)['nom'] ?? '', style: const TextStyle(color: Color(0xFF0D7377), fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(width: 8), Text((liv['livreur'] as Map)['telephone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12))])],
      ])));
  }

  Widget _conteneur({required String titre, required Widget child}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377))), const SizedBox(height: 12), child]));

  Widget _champ(TextEditingController ctrl, String label, IconData icone, Color couleur, {TextInputType clavier = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: clavier, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone, color: couleur, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
      filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));

  Widget _etatVide(String msg, IconData ic) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(ic, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text(msg, style: TextStyle(color: Colors.grey.shade400))]));
  String _fmt(dynamic m) { if (m == null) return '0'; final v = (m as num).toInt(); return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} '); }
}