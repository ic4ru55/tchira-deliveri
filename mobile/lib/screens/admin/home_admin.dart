import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {

  // Navigation bottom bar style TikTok
  int _ongletActif = 0;

  // Stats
  Map<String, dynamic> _stats           = {};
  bool                 _chargementStats = true;
  DateTime?            _dateFiltre;   // ✅ filtre date dashboard

  // Utilisateurs
  List<dynamic> _utilisateurs    = [];
  bool          _chargementUsers = true;
  String        _filtreRole      = 'tous';

  // Livraisons
  List<dynamic> _toutesLivraisons    = [];
  bool          _chargementLivraisons = true;
  String        _filtreStatut        = 'tous';

  // Tarifs
  List<dynamic> _tarifs         = [];
  List<dynamic> _zones          = [];
  bool          _chargementTarifs = true;

  // Formulaire nouvel utilisateur
  final _nomCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl   = TextEditingController();
  final _telCtrl   = TextEditingController();
  String _roleNouvel      = 'livreur';
  bool   _formUserVisible = false;
  bool   _creationEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerStats();
    _chargerUtilisateurs();
    _chargerLivraisons();
    _chargerTarifs();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  // ─── Chargements ──────────────────────────────────────────────────────────
  Future<void> _chargerStats({String? date}) async {
    setState(() => _chargementStats = true);
    try {
      final reponse = await ApiService.getStats(date: date);
      if (reponse['success'] == true) {
        setState(() {
          _stats           = reponse['stats'];
          _chargementStats = false;
        });
      } else {
        setState(() => _chargementStats = false);
      }
    } catch (e) {
      setState(() => _chargementStats = false);
    }
  }

  Future<void> _chargerUtilisateurs({String? role}) async {
    setState(() => _chargementUsers = true);
    try {
      final reponse = await ApiService.getUtilisateurs(
        role: role == 'tous' ? null : role,
      );
      if (reponse['success'] == true) {
        setState(() {
          _utilisateurs    = reponse['utilisateurs'];
          _chargementUsers = false;
        });
      } else {
        setState(() => _chargementUsers = false);
      }
    } catch (e) {
      setState(() => _chargementUsers = false);
    }
  }

  Future<void> _chargerLivraisons({String? statut}) async {
    setState(() => _chargementLivraisons = true);
    try {
      final reponse = await ApiService.toutesLesLivraisons(
        statut: statut == 'tous' ? null : statut,
      );
      if (reponse['success'] == true) {
        setState(() {
          _toutesLivraisons     = reponse['livraisons'];
          _chargementLivraisons = false;
        });
      } else {
        setState(() => _chargementLivraisons = false);
      }
    } catch (e) {
      setState(() => _chargementLivraisons = false);
    }
  }

  Future<void> _chargerTarifs() async {
    setState(() => _chargementTarifs = true);
    try {
      final reponse = await ApiService.getTarifs();
      if (reponse['success'] == true) {
        setState(() {
          _tarifs          = reponse['tarifs'] ?? [];
          _zones           = reponse['zones']  ?? [];
          _chargementTarifs = false;
        });
      } else {
        setState(() => _chargementTarifs = false);
      }
    } catch (e) {
      setState(() => _chargementTarifs = false);
    }
  }

  // ─── Filtre date dashboard ────────────────────────────────────────────────
  Future<void> _choisirDate() async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  _dateFiltre ?? DateTime.now(),
      firstDate:    DateTime(2024),
      lastDate:     DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   Color(0xFF0D7377),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _dateFiltre = picked);
    final dateStr =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _chargerStats(date: dateStr);
  }

  Future<void> _reinitialiserDate() async {
    setState(() => _dateFiltre = null);
    await _chargerStats();
  }

  // ─── Actions utilisateurs ─────────────────────────────────────────────────
  Future<void> _creerUtilisateur() async {
    if (_nomCtrl.text.isEmpty || _emailCtrl.text.isEmpty ||
        _mdpCtrl.text.isEmpty || _telCtrl.text.isEmpty) {
      _snack('Remplis tous les champs', Colors.red);
      return;
    }
    setState(() => _creationEnCours = true);
    try {
      final reponse = await ApiService.creerUtilisateur(
        nom:        _nomCtrl.text.trim(),
        email:      _emailCtrl.text.trim(),
        motDePasse: _mdpCtrl.text.trim(),
        telephone:  _telCtrl.text.trim(),
        role:       _roleNouvel,
      );
      if (!mounted) return;
      if (reponse['success'] == true) {
        _nomCtrl.clear(); _emailCtrl.clear();
        _mdpCtrl.clear(); _telCtrl.clear();
        setState(() => _formUserVisible = false);
        _snack('✅ Compte créé avec succès !', Colors.green);
        _chargerUtilisateurs();
      } else {
        _snack(reponse['message'] ?? 'Erreur création', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _creationEnCours = false);
    }
  }

  // ✅ FIX SUSPENDRE : on affiche maintenant toujours le résultat
  // Avant : si success != true, rien ne se passait
  // Maintenant : on affiche le message d'erreur et on recharge quand même
  Future<void> _changerStatut(String userId, bool actif) async {
    // Feedback visuel immédiat — optimistic update
    final index = _utilisateurs.indexWhere((u) => u['_id'] == userId);
    if (index != -1) {
      setState(() => _utilisateurs[index] = {
        ..._utilisateurs[index],
        'actif': actif,
      });
    }

    try {
      final reponse = await ApiService.changerStatutCompte(
        userId: userId,
        actif:  actif,
      );
      if (!mounted) return;

      if (reponse['success'] == true) {
        _snack(
          actif ? '✅ Compte réactivé' : '🚫 Compte suspendu',
          actif ? Colors.green : Colors.orange,
        );
      } else {
        // ✅ Annuler l'optimistic update si erreur
        _snack(reponse['message'] ?? 'Erreur lors de la modification', Colors.red);
        if (index != -1) {
          setState(() => _utilisateurs[index] = {
            ..._utilisateurs[index],
            'actif': !actif, // remettre l'ancienne valeur
          });
        }
      }
      // Recharger pour être en sync avec le serveur
      _chargerUtilisateurs(role: _filtreRole == 'tous' ? null : _filtreRole);
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur réseau', Colors.red);
      // Annuler optimistic update
      if (index != -1) {
        setState(() => _utilisateurs[index] = {
          ..._utilisateurs[index],
          'actif': !actif,
        });
      }
    }
  }

  Future<void> _supprimerUtilisateur(String userId, String nom) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Confirmer la suppression'),
        content: Text('Supprimer le compte de $nom ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      final reponse = await ApiService.supprimerUtilisateur(userId);
      if (!mounted) return;
      if (reponse['success'] == true) {
        _snack('Compte supprimé', Colors.red);
        _chargerUtilisateurs(role: _filtreRole == 'tous' ? null : _filtreRole);
      } else {
        _snack(reponse['message'] ?? 'Erreur suppression', Colors.red);
      }
    } catch (e) {
      _snack('Erreur réseau', Colors.red);
    }
  }

  void _snack(String msg, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: couleur),
    );
  }

  Future<void> _deconnecter() async {
    await context.read<AuthProvider>().deconnecter();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Corps selon onglet actif
    final pages = [
      _ongletDashboard(),
      _ongletComptes(),
      _ongletLivraisons(),
      _ongletTarifs(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ─── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D7377),
        elevation: 0,
        title: Row(children: [
          // Mini logo dans l'AppBar
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tchira Express',
                style: TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(auth.user?.nom ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _chargerStats();
              _chargerUtilisateurs();
              _chargerLivraisons();
              _chargerTarifs();
            },
          ),
          IconButton(
            icon:      const Icon(Icons.logout, color: Colors.white),
            onPressed: _deconnecter,
          ),
        ],
      ),

      // ─── Contenu ─────────────────────────────────────────────────────────
      body: pages[_ongletActif],

      // ─── Bottom Navigation Bar style TikTok ──────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset:     const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.dashboard_rounded,      Icons.dashboard_outlined,      'Dashboard'),
                _navItem(1, Icons.people_rounded,          Icons.people_outline,           'Comptes'),
                _navItem(2, Icons.local_shipping_rounded,  Icons.local_shipping_outlined,  'Livraisons'),
                _navItem(3, Icons.price_change_rounded,    Icons.price_change_outlined,    'Tarifs'),
              ],
            ),
          ),
        ),
      ),

      // FAB sur l'onglet Comptes
      floatingActionButton: _ongletActif == 1
          ? FloatingActionButton.extended(
              onPressed: () =>
                  setState(() => _formUserVisible = !_formUserVisible),
              backgroundColor: const Color(0xFFF97316),
              icon:  Icon(_formUserVisible ? Icons.close : Icons.person_add),
              label: Text(_formUserVisible ? 'Annuler' : 'Nouveau compte'),
            )
          : null,
    );
  }

  // ─── Item navigation bottom bar ───────────────────────────────────────────
  Widget _navItem(int index, IconData iconeActif, IconData iconeInactif,
      String label) {
    final actif  = _ongletActif == index;
    final couleur = actif ? const Color(0xFF0D7377) : Colors.grey.shade400;

    return GestureDetector(
      onTap: () => setState(() => _ongletActif = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:        actif
              ? const Color(0xFF0D7377).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(actif ? iconeActif : iconeInactif, color: couleur, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            color:      couleur,
            fontSize:   10,
            fontWeight: actif ? FontWeight.w700 : FontWeight.normal,
          )),
          // ✅ Indicateur actif style TikTok
          if (actif)
            Container(
              margin:    const EdgeInsets.only(top: 3),
              width:     18, height: 3,
              decoration: BoxDecoration(
                color:        const Color(0xFF0D7377),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── Onglet Dashboard ─────────────────────────────────────────────────────
  Widget _ongletDashboard() {
    if (_chargementStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _chargerStats(
        date: _dateFiltre != null
            ? '${_dateFiltre!.year}-${_dateFiltre!.month.toString().padLeft(2, '0')}-${_dateFiltre!.day.toString().padLeft(2, '0')}'
            : null,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Titre + filtre date ──────────────────────────────────────────
          Row(children: [
            const Text('📊 Vue d\'ensemble',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF0D7377))),
            const Spacer(),
            // ✅ Bouton filtre par date
            GestureDetector(
              onTap: _choisirDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        _dateFiltre != null
                      ? const Color(0xFF0D7377)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today,
                      size: 14,
                      color: _dateFiltre != null ? Colors.white : Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    _dateFiltre != null
                        ? '${_dateFiltre!.day}/${_dateFiltre!.month}/${_dateFiltre!.year}'
                        : 'Filtrer par date',
                    style: TextStyle(
                      fontSize:   12,
                      color:      _dateFiltre != null ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
            ),
            // Bouton reset date
            if (_dateFiltre != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _reinitialiserDate,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                ),
              ),
            ],
          ]),

          // Badge date active
          if (_dateFiltre != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        const Color(0xFFF97316).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.filter_alt, size: 14, color: Color(0xFFF97316)),
                const SizedBox(width: 6),
                Text(
                  'Statistiques du ${_dateFiltre!.day}/${_dateFiltre!.month}/${_dateFiltre!.year}',
                  style: const TextStyle(
                      color: Color(0xFFF97316), fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // ── CA Cards ─────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _carteStatCA(
              titre:   _dateFiltre != null ? 'CA ce jour' : 'CA Total',
              montant: _stats['chiffreAffaires'] ?? 0,
              icone:   Icons.account_balance_wallet,
              couleur: const Color(0xFF0D7377),
            )),
            const SizedBox(width: 12),
            Expanded(child: _carteStatCA(
              titre:   'CA Aujourd\'hui',
              montant: _stats['caAujourdhui'] ?? 0,
              icone:   Icons.today,
              couleur: const Color(0xFFF97316),
            )),
          ]),
          const SizedBox(height: 8),

          // CA Total tous les temps (si filtre date actif)
          if (_dateFiltre != null) ...[
            _carteStatCA(
              titre:   'CA Total tous les temps',
              montant: _stats['caTotal'] ?? 0,
              icone:   Icons.bar_chart,
              couleur: Colors.purple,
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 4),

          // ── Grille stats ──────────────────────────────────────────────────
          GridView.count(
            crossAxisCount:   2,
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
            childAspectRatio: 1.6,
            children: [
              _carteStatNombre(label: 'Total',
                  valeur: _stats['total'] ?? 0,
                  couleur: Colors.blueGrey, icone: Icons.all_inbox),
              _carteStatNombre(label: 'En attente',
                  valeur: _stats['enAttente'] ?? 0,
                  couleur: Colors.orange, icone: Icons.hourglass_top),
              _carteStatNombre(label: 'En cours',
                  valeur: _stats['enCours'] ?? 0,
                  couleur: const Color(0xFF0D7377), icone: Icons.sync),
              _carteStatNombre(label: 'En livraison',
                  valeur: _stats['enLivraison'] ?? 0,
                  couleur: Colors.purple, icone: Icons.local_shipping),
              _carteStatNombre(label: 'Livrées',
                  valeur: _stats['livrees'] ?? 0,
                  couleur: Colors.green, icone: Icons.check_circle),
              _carteStatNombre(label: 'Annulées',
                  valeur: _stats['annulees'] ?? 0,
                  couleur: Colors.red, icone: Icons.cancel),
            ],
          ),
          const SizedBox(height: 12),

          // Livreurs actifs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delivery_dining,
                    color: Color(0xFF0D7377), size: 28),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_stats['livreursActifs'] ?? 0}',
                    style: const TextStyle(fontSize: 28,
                        fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                const Text('Livreurs actifs',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ─── Onglet Comptes ───────────────────────────────────────────────────────
  Widget _ongletComptes() {
    return Column(children: [
      Container(
        color:   Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['tous', 'livreur', 'receptionniste', 'client', 'admin']
                .map((role) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label:          Text(_labelRole(role)),
                        selected:       _filtreRole == role,
                        selectedColor:  const Color(0xFF0D7377).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF0D7377),
                        onSelected: (_) {
                          setState(() => _filtreRole = role);
                          _chargerUtilisateurs(role: role == 'tous' ? null : role);
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ),

      if (_formUserVisible)
        Container(
          margin:  const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👤 Nouveau compte',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                    color: Color(0xFF0D7377))),
            const SizedBox(height: 12),
            _champTexte(ctrl: _nomCtrl, label: 'Nom complet',
                icone: Icons.person_outlined, couleurIcone: const Color(0xFF0D7377)),
            const SizedBox(height: 10),
            _champTexte(ctrl: _emailCtrl, label: 'Email',
                icone: Icons.email_outlined, couleurIcone: const Color(0xFF0D7377),
                clavier: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _champTexte(ctrl: _telCtrl, label: 'Téléphone',
                icone: Icons.phone_outlined, couleurIcone: const Color(0xFF0D7377),
                clavier: TextInputType.phone),
            const SizedBox(height: 10),
            _champTexte(ctrl: _mdpCtrl, label: 'Mot de passe',
                icone: Icons.lock_outlined, couleurIcone: const Color(0xFF0D7377)),
            const SizedBox(height: 12),
            Row(
              children: ['livreur', 'receptionniste', 'admin'].map((role) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label:         Text(_labelRole(role)),
                      selected:      _roleNouvel == role,
                      selectedColor: const Color(0xFFF97316),
                      labelStyle: TextStyle(
                          color: _roleNouvel == role ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _roleNouvel = role),
                    ),
                  )).toList(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                onPressed: _creationEnCours ? null : _creerUtilisateur,
                icon: _creationEnCours
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.person_add, size: 18),
                label: const Text('Créer le compte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7377),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),

      Expanded(
        child: _chargementUsers
            ? const Center(child: CircularProgressIndicator())
            : _utilisateurs.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Aucun utilisateur',
                          style: TextStyle(color: Colors.grey.shade400)),
                    ]))
                : ListView.builder(
                    padding:   const EdgeInsets.all(16),
                    itemCount: _utilisateurs.length,
                    itemBuilder: (context, index) =>
                        _carteUtilisateur(_utilisateurs[index]),
                  ),
      ),
    ]);
  }

  // ─── Onglet Livraisons ────────────────────────────────────────────────────
  Widget _ongletLivraisons() {
    return Column(children: [
      Container(
        color:   Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['tous', 'en_attente', 'en_cours',
                       'en_livraison', 'livre', 'annule']
                .map((statut) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label:          Text(_labelStatut(statut)),
                        selected:       _filtreStatut == statut,
                        selectedColor:  _couleurStatut(statut).withValues(alpha: 0.15),
                        checkmarkColor: _couleurStatut(statut),
                        onSelected: (_) {
                          setState(() => _filtreStatut = statut);
                          _chargerLivraisons(
                              statut: statut == 'tous' ? null : statut);
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ),

      Expanded(
        child: _chargementLivraisons
            ? const Center(child: CircularProgressIndicator())
            : _toutesLivraisons.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Aucune livraison',
                          style: TextStyle(color: Colors.grey.shade400)),
                    ]))
                : RefreshIndicator(
                    onRefresh: _chargerLivraisons,
                    child: ListView.builder(
                      padding:   const EdgeInsets.all(16),
                      itemCount: _toutesLivraisons.length,
                      itemBuilder: (context, index) =>
                          _carteLivraison(_toutesLivraisons[index]),
                    ),
                  ),
      ),
    ]);
  }

  // ─── Onglet Tarifs ────────────────────────────────────────────────────────
  Widget _ongletTarifs() {
    if (_chargementTarifs) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _chargerTarifs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📦 Catégories de colis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF0D7377))),
          const SizedBox(height: 4),
          const Text('Appuie sur ✏️ pour modifier le prix',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          ..._tarifs.map((t) => _carteTarif(Map<String, dynamic>.from(t as Map))),
          const SizedBox(height: 24),
          const Text('🗺️ Zones de livraison',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF0D7377))),
          const SizedBox(height: 4),
          const Text('Appuie sur ✏️ pour modifier les frais',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          ..._zones.map((z) => _carteZone(Map<String, dynamic>.from(z as Map))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ─── Carte tarif ──────────────────────────────────────────────────────────
  Widget _carteTarif(Map<String, dynamic> tarif) {
    final surDevis = tarif['sur_devis'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D7377).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.inventory_2, color: Color(0xFF0D7377), size: 22),
        ),
        title: Text(tarif['label'] ?? tarif['categorie'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          surDevis ? 'Sur devis' : '${_formatPrix(tarif['prix_base'])} FCFA',
          style: TextStyle(
            color: surDevis ? Colors.orange : const Color(0xFF0D7377),
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF0D7377)),
          onPressed: () => _dialogModifierTarif(tarif),
        ),
      ),
    );
  }

  // ─── Carte zone ───────────────────────────────────────────────────────────
  Widget _carteZone(Map<String, dynamic> zone) {
    final frais = (zone['frais_supplementaires'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.map_outlined, color: Color(0xFFF97316), size: 22),
        ),
        title: Text(zone['nom'] ?? zone['code'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(zone['description'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(frais == 0 ? 'Inclus' : '+${_formatPrix(frais)} FCFA',
              style: TextStyle(
                color: frais == 0 ? Colors.green : const Color(0xFFF97316),
                fontWeight: FontWeight.bold, fontSize: 13,
              )),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFF97316)),
            onPressed: () => _dialogModifierZone(zone),
          ),
        ]),
      ),
    );
  }

  // ─── Dialog modifier tarif ────────────────────────────────────────────────
  Future<void> _dialogModifierTarif(Map<String, dynamic> tarif) async {
    final prixCtrl = TextEditingController(
        text: (tarif['prix_base'] ?? 0).toString());
    bool surDevis = tarif['sur_devis'] == true;
    bool enCours  = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Modifier — ${tarif['label'] ?? tarif['categorie']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF0D7377))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: prixCtrl, keyboardType: TextInputType.number,
              enabled: !surDevis,
              decoration: InputDecoration(
                labelText: 'Prix de base (FCFA)',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Switch(
                value: surDevis,
                activeThumbColor: const Color(0xFFF97316),
                activeTrackColor: const Color(0xFFF97316).withValues(alpha: 0.4),
                onChanged: (val) => setDialogState(() => surDevis = val),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Sur devis uniquement')),
            ]),
            if (surDevis)
              const Text('Le client devra contacter l\'admin pour le prix.',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: enCours ? null : () async {
                setDialogState(() => enCours = true);
                final prix = double.tryParse(prixCtrl.text.trim()) ?? 0;
                final nav       = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final reponse = await ApiService.modifierTarif(
                    categorie: tarif['categorie'], prixBase: prix, surDevis: surDevis);
                nav.pop();
                if (reponse['success'] == true) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('✅ Tarif mis à jour !'),
                      backgroundColor: Colors.green));
                  if (mounted) _chargerTarifs();
                } else {
                  messenger.showSnackBar(SnackBar(
                      content: Text(reponse['message'] ?? 'Erreur'),
                      backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7377),
                  foregroundColor: Colors.white),
              child: enCours
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    prixCtrl.dispose();
  }

  // ─── Dialog modifier zone ─────────────────────────────────────────────────
  Future<void> _dialogModifierZone(Map<String, dynamic> zone) async {
    final fraisCtrl = TextEditingController(
        text: (zone['frais_supplementaires'] ?? 0).toString());
    bool enCours = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Modifier — ${zone['nom'] ?? zone['code']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF0D7377))),
          content: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(zone['description'] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: fraisCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:  'Frais supplémentaires (FCFA)',
                prefixIcon: const Icon(Icons.add_road),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                helperText: 'Mettre 0 si inclus dans le prix de base',
                suffixText: 'FCFA',
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: enCours ? null : () async {
                setDialogState(() => enCours = true);
                final frais = int.tryParse(fraisCtrl.text.trim()) ?? 0;
                final nav       = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final reponse = await ApiService.modifierZone(
                    code: zone['code'], fraisSupplementaires: frais);
                nav.pop();
                if (reponse['success'] == true) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('✅ Zone mise à jour !'),
                      backgroundColor: Colors.green));
                  if (mounted) _chargerTarifs();
                } else {
                  messenger.showSnackBar(SnackBar(
                      content: Text(reponse['message'] ?? 'Erreur'),
                      backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white),
              child: enCours
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    fraisCtrl.dispose();
  }

  // ─── Widgets communs ──────────────────────────────────────────────────────
  Widget _carteStatCA({required String titre, required dynamic montant,
      required IconData icone, required Color couleur}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: couleur, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: Colors.white70, size: 22),
        const SizedBox(height: 8),
        Text('${_formatPrix(montant)} FCFA',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(titre, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _carteStatNombre({required String label, required dynamic valeur,
      required Color couleur, required IconData icone}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: couleur, size: 20),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$valeur', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: couleur)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _carteUtilisateur(Map<String, dynamic> user) {
    final actif = user['actif'] as bool? ?? false;
    final role  = user['role']  as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _couleurRole(role).withValues(alpha: 0.15),
          child: Icon(_iconeRole(role), color: _couleurRole(role), size: 22),
        ),
        title: Row(children: [
          Expanded(child: Text(user['nom'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _couleurRole(role).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_labelRole(role),
                style: TextStyle(color: _couleurRole(role),
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(user['email'] ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if ((user['telephone'] as String? ?? '').isNotEmpty)
            Text(user['telephone'],
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          // ✅ Badge statut visible
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: actif
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              actif ? '● Actif' : '● Suspendu',
              style: TextStyle(
                color:      actif ? Colors.green : Colors.red,
                fontSize:   10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(
              actif ? Icons.block : Icons.check_circle,
              color: actif ? Colors.orange : Colors.green, size: 20,
            ),
            onPressed: () => _changerStatut(user['_id'], !actif),
            tooltip: actif ? 'Suspendre' : 'Réactiver',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _supprimerUtilisateur(user['_id'], user['nom'] ?? ''),
            tooltip: 'Supprimer',
          ),
        ]),
      ),
    );
  }

  Widget _carteLivraison(Map<String, dynamic> livraison) {
    final statut  = livraison['statut'] as String? ?? '';
    final couleur = _couleurStatut(statut);
    final label   = _labelStatut(statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label, style: TextStyle(
                  color: couleur, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            Text('${_formatPrix(livraison['prix'])} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Color(0xFF0D7377))),
          ]),
          const SizedBox(height: 8),
          _adresseLigne(icone: Icons.trip_origin, couleur: Colors.green,
              texte: livraison['adresse_depart'] ?? ''),
          const SizedBox(height: 4),
          _adresseLigne(icone: Icons.location_on, couleur: Colors.red,
              texte: livraison['adresse_arrivee'] ?? ''),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.person, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Text(livraison['client'] is Map
                ? (livraison['client'] as Map)['nom'] ?? '' : '',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 12),
            if (livraison['livreur'] is Map) ...[
              const Icon(Icons.delivery_dining, size: 13, color: Color(0xFF0D7377)),
              const SizedBox(width: 4),
              Text((livraison['livreur'] as Map)['nom'] ?? '',
                  style: const TextStyle(color: Color(0xFF0D7377), fontSize: 12)),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _champTexte({required TextEditingController ctrl, required String label,
      required IconData icone, required Color couleurIcone,
      TextInputType clavier = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: clavier,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icone, color: couleurIcone, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _adresseLigne({required IconData icone, required Color couleur,
      required String texte}) {
    return Row(children: [
      Icon(icone, color: couleur, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(texte,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          overflow: TextOverflow.ellipsis)),
    ]);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _formatPrix(dynamic montant) {
    if (montant == null) return '0';
    final val = (montant as num).toInt();
    return val.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  String _labelRole(String role) {
    switch (role) {
      case 'tous': return 'Tous'; case 'livreur': return 'Livreur';
      case 'receptionniste': return 'Réceptionniste'; case 'client': return 'Client';
      case 'admin': return 'Admin'; default: return role;
    }
  }

  Color _couleurRole(String role) {
    switch (role) {
      case 'livreur': return const Color(0xFF0D7377);
      case 'receptionniste': return const Color(0xFFF97316);
      case 'client': return Colors.blue; case 'admin': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _iconeRole(String role) {
    switch (role) {
      case 'livreur': return Icons.delivery_dining;
      case 'receptionniste': return Icons.headset_mic;
      case 'client': return Icons.person;
      case 'admin': return Icons.admin_panel_settings;
      default: return Icons.person;
    }
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'tous': return Colors.blueGrey; case 'en_attente': return Colors.orange;
      case 'en_cours': return const Color(0xFF0D7377);
      case 'en_livraison': return Colors.purple;
      case 'livre': return Colors.green; case 'annule': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _labelStatut(String statut) {
    switch (statut) {
      case 'tous': return 'Tous'; case 'en_attente': return '⏳ Attente';
      case 'en_cours': return '🔄 En cours'; case 'en_livraison': return '🚚 Livraison';
      case 'livre': return '✅ Livré'; case 'annule': return '❌ Annulé';
      default: return statut;
    }
  }
}