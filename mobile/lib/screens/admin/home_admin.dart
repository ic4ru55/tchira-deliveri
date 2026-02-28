import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../screens/auth/login_screen.dart';
import '../profil_page.dart';
import '../validation_paiement_screen.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});
  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  int _ongletActif = 0; // 0=Dashboard 1=Comptes 2=Livraisons 3=Tarifs 4=Profil

  Map<String, dynamic> _stats           = {};
  bool _chargementStats                 = true;
  List<Map<String, dynamic>> _statsJours = []; // CA par jour sur 7 jours
  List<Map<String, dynamic>> _topLivreurs = []; // top livreurs
  bool _exportEnCours                   = false;
  List<dynamic> _utilisateurs           = [];
  bool _chargementUsers                 = true;
  String _filtreRole                    = 'tous';
  List<dynamic> _toutesLivraisons       = [];
  bool _chargementLivraisons            = true;
  String _filtreStatut                  = 'tous';
  List<dynamic> _tarifs                 = [];
  List<dynamic> _zones                  = [];
  bool _chargementTarifs                = true;

  final _nomCtrl    = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _mdpCtrl    = TextEditingController();
  final _telCtrl    = TextEditingController();
  String _roleNouvel      = 'livreur';
  bool   _formUserVisible = false;
  bool   _creationEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerStats(); _chargerUtilisateurs(); _chargerLivraisons(); _chargerTarifs();
  }

  @override
  void dispose() { _nomCtrl.dispose(); _emailCtrl.dispose(); _mdpCtrl.dispose(); _telCtrl.dispose(); super.dispose(); }

  Future<void> _chargerStats() async {
    setState(() => _chargementStats = true);
    try {
      final r = await ApiService.getStats();
      if (r['success'] == true && mounted) {
        final stats = r['stats'] as Map<String, dynamic>;
        // Construire graphique 7 jours depuis statsParJour si disponible
        final jours = stats['statsParJour'] as List<dynamic>? ?? [];
        final top   = stats['topLivreurs']  as List<dynamic>? ?? [];
        setState(() {
          _stats       = stats;
          _statsJours  = jours.map((j) => Map<String, dynamic>.from(j as Map)).toList();
          _topLivreurs = top.map((t)  => Map<String, dynamic>.from(t as Map)).toList();
          _chargementStats = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _chargementStats = false); }
  }

  // ── Export CSV des livraisons ────────────────────────────────────────────
  Future<void> _exportCSV() async {
    setState(() => _exportEnCours = true);
    try {
      List<dynamic> livs;
      if (_toutesLivraisons.isNotEmpty) {
        livs = _toutesLivraisons;
      } else {
        final r = await ApiService.toutesLesLivraisons();
        livs = r['success'] == true ? (r['livraisons'] as List<dynamic>? ?? []) : <dynamic>[];
      }

      final sb = StringBuffer();
      sb.writeln('ID,Statut,Client,Livreur,Depart,Arrivee,Prix,Date');
      for (final l in livs) {
        final m = l as Map<String, dynamic>;
        final client  = (m['client']  is Map) ? (m['client']  as Map)['nom'] ?? '' : '';
        final livreur = (m['livreur'] is Map) ? (m['livreur'] as Map)['nom'] ?? '' : '';
        final id   = (m['_id'] as String? ?? '').substring(0, 8);
        final prix = (m['prix'] as num?)?.toInt() ?? 0;
        final date = (m['createdAt'] as String? ?? '').split('T').first;
        sb.writeln('$id,${m['statut']},${_csvEscape(client as String)},${_csvEscape(livreur as String)},'
            '${_csvEscape(m['adresse_depart'] as String? ?? '')},'
            '${_csvEscape(m['adresse_arrivee'] as String? ?? '')},$prix,$date');
      }

      await Share.share(
        sb.toString(),
        subject: 'Livraisons Tchira Express — ${DateTime.now().toString().split(" ").first}',
      );
    } finally { if (mounted) setState(() => _exportEnCours = false); }
  }

  String _csvEscape(String s) => s.contains(',') ? '"$s"' : s;

  Future<void> _chargerUtilisateurs({String? role}) async {
    setState(() => _chargementUsers = true);
    try { final r = await ApiService.getUtilisateurs(role: role == 'tous' ? null : role);
      if (r['success'] == true) setState(() { _utilisateurs = r['utilisateurs']; _chargementUsers = false; }); }
    catch (_) { if (mounted) setState(() => _chargementUsers = false); }
  }

  Future<void> _chargerLivraisons({String? statut}) async {
    setState(() => _chargementLivraisons = true);
    try { final r = await ApiService.toutesLesLivraisons(statut: statut == 'tous' ? null : statut);
      if (r['success'] == true) setState(() { _toutesLivraisons = r['livraisons']; _chargementLivraisons = false; }); }
    catch (_) { if (mounted) setState(() => _chargementLivraisons = false); }
  }

  Future<void> _chargerTarifs() async {
    setState(() => _chargementTarifs = true);
    try { final r = await ApiService.getTarifs();
      if (r['success'] == true) setState(() { _tarifs = r['tarifs'] ?? []; _zones = r['zones'] ?? []; _chargementTarifs = false; }); }
    catch (_) { if (mounted) setState(() => _chargementTarifs = false); }
  }

  Future<void> _creerUtilisateur() async {
    if (_nomCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _mdpCtrl.text.isEmpty || _telCtrl.text.isEmpty) { _snack('Remplis tous les champs', Colors.red); return; }
    setState(() => _creationEnCours = true);
    try {
      final r = await ApiService.creerUtilisateur(nom: _nomCtrl.text.trim(), email: _emailCtrl.text.trim(), motDePasse: _mdpCtrl.text.trim(), telephone: _telCtrl.text.trim(), role: _roleNouvel);
      if (!mounted) return;
      if (r['success'] == true) { _nomCtrl.clear(); _emailCtrl.clear(); _mdpCtrl.clear(); _telCtrl.clear(); setState(() => _formUserVisible = false); _snack('✅ Compte créé !', Colors.green); _chargerUtilisateurs(); }
      else _snack(r['message'] ?? 'Erreur', Colors.red);
    } finally { if (mounted) setState(() => _creationEnCours = false); }
  }

  Future<void> _changerStatut(String userId, bool actif) async {
    try { final r = await ApiService.changerStatutCompte(userId: userId, actif: actif);
      if (!mounted) return;
      if (r['success'] == true) { _snack(actif ? '✅ Compte réactivé' : '🚫 Compte suspendu', actif ? Colors.green : Colors.orange); _chargerUtilisateurs(role: _filtreRole == 'tous' ? null : _filtreRole); }
    } catch (_) { _snack('Erreur réseau', Colors.red); }
  }

  Future<void> _supprimerUtilisateur(String id, String nom) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirmer la suppression'),
      content: Text('Supprimer le compte de $nom ?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer'))],
    ));
    if (ok != true) return;
    try { final r = await ApiService.supprimerUtilisateur(id);
      if (!mounted) return;
      if (r['success'] == true) { _snack('Compte supprimé', Colors.red); _chargerUtilisateurs(role: _filtreRole == 'tous' ? null : _filtreRole); }
    } catch (_) { _snack('Erreur réseau', Colors.red); }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pages = [_ongletDashboard(), _ongletComptes(), _ongletLivraisons(), _ongletTarifs(), const ValidationPaiementScreen(), ProfilPage(
          role: 'admin',
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3A6B), foregroundColor: Colors.white),
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
      floatingActionButton: _ongletActif == 1
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _formUserVisible = !_formUserVisible),
              backgroundColor: const Color(0xFFF97316),
              icon: Icon(_formUserVisible ? Icons.close : Icons.person_add),
              label: Text(_formUserVisible ? 'Annuler' : 'Nouveau compte'))
          : null,
    ),
    );
  }

  Widget _navbar() {
    final items = [
      {'icon': Icons.dashboard_outlined,    'iconSel': Icons.dashboard,     'label': 'Dashboard'},
      {'icon': Icons.people_outline,        'iconSel': Icons.people,        'label': 'Comptes'},
      {'icon': Icons.list_alt_outlined,     'iconSel': Icons.list_alt,      'label': 'Livraisons'},
      {'icon': Icons.price_change_outlined, 'iconSel': Icons.price_change,  'label': 'Tarifs'},
      {'icon': Icons.verified_outlined,     'iconSel': Icons.verified,      'label': 'Paiements'},
      {'icon': Icons.person_outline,        'iconSel': Icons.person,        'label': 'Profil'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Indicateur position scrollable ────────────────────────────────────
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
                borderRadius: BorderRadius.circular(2)),
            ))),
        ),
        // ── Onglets scrollables ───────────────────────────────────────────────
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection:  Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final sel = _ongletActif == i;
              return GestureDetector(
                onTap: () => setState(() => _ongletActif = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF0D7377) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: sel ? null : Border.all(
                        color: Colors.grey.shade200, width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      sel ? items[i]['iconSel'] as IconData
                          : items[i]['icon'] as IconData,
                      color: sel ? Colors.white : Colors.grey.shade600,
                      size: 18),
                    const SizedBox(width: 6),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
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

  Widget _header(String titre, {Widget? action}) => Container(
    width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
    decoration: const BoxDecoration(color: Color(0xFF0D7377), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(titre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      action ?? IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: () { _chargerStats(); _chargerUtilisateurs(); _chargerLivraisons(); _chargerTarifs(); }),
    ]),
  );

  Widget _ongletDashboard() {
    if (_chargementStats) return Column(children: [_header('Dashboard 📊'), const Expanded(child: Center(child: CircularProgressIndicator()))]);
    return Column(children: [
      _header('Dashboard 📊', action: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_exportEnCours)
          const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
        else
          IconButton(icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 22),
              tooltip: 'Exporter CSV', onPressed: _exportCSV),
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _chargerStats),
      ])),
      Expanded(child: RefreshIndicator(onRefresh: _chargerStats, child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── CA Cards ────────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _carteCA(titre: 'CA Total', montant: _stats['chiffreAffaires'] ?? 0,
                icone: Icons.account_balance_wallet, couleur: const Color(0xFF0D7377))),
            const SizedBox(width: 12),
            Expanded(child: _carteCA(titre: 'Aujourd\'hui', montant: _stats['caAujourdhui'] ?? 0,
                icone: Icons.today, couleur: const Color(0xFFF97316))),
          ]),
          const SizedBox(height: 12),

          // ── Grille statuts ───────────────────────────────────────────────────
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6, children: [
            _carteStat('Total', _stats['total'] ?? 0, Colors.blueGrey, Icons.all_inbox),
            _carteStat('En attente', _stats['enAttente'] ?? 0, Colors.orange, Icons.hourglass_top),
            _carteStat('En cours', _stats['enCours'] ?? 0, const Color(0xFF0D7377), Icons.sync),
            _carteStat('En livraison', _stats['enLivraison'] ?? 0, Colors.purple, Icons.local_shipping),
            _carteStat('Livrées', _stats['livrees'] ?? 0, Colors.green, Icons.check_circle),
            _carteStat('Annulées', _stats['annulees'] ?? 0, Colors.red, Icons.cancel),
          ]),
          const SizedBox(height: 20),

          // ── Graphique CA 7 jours ─────────────────────────────────────────────
          _graphiqueCA(),
          const SizedBox(height: 20),

          // ── Top Livreurs ─────────────────────────────────────────────────────
          if (_topLivreurs.isNotEmpty) ...[
            _topLivreursWidget(),
            const SizedBox(height: 16),
          ],
        ]),
      ))),
    ]);
  }

  // ── Graphique fl_chart ──────────────────────────────────────────────────────
  Widget _graphiqueCA() {
    final hasData = _statsJours.isNotEmpty;
    // Données factices si API ne retourne pas encore statsParJour
    final spots = hasData
        ? _statsJours.asMap().entries.map((e) {
            final ca = (e.value['ca'] as num?)?.toDouble() ?? 0;
            return FlSpot(e.key.toDouble(), ca);
          }).toList()
        : [FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), FlSpot(4, 0), FlSpot(5, 0), FlSpot(6, 0)];

    final labels = hasData
        ? _statsJours.map((j) {
            final d = (j['date'] as String? ?? '').split('-');
            return d.length >= 3 ? '${d[2]}/${d[1]}' : '';
          }).toList()
        : ['J-6','J-5','J-4','J-3','J-2','J-1','Auj'];

    final maxY = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('📈 CA — 7 derniers jours',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D7377))),
          Text('FCFA', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            minY: 0, maxY: maxY > 0 ? maxY * 1.2 : 10000,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 2500,
              getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[i], style: TextStyle(fontSize: 10, color: Colors.grey.shade500)));
                  })),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42,
                  getTitlesWidget: (v, _) => Text(_fmtK(v),
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400)))),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '${_fmt(s.y)} FCFA',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))).toList())),
            lineBarsData: [LineChartBarData(
              spots: spots,
              isCurved: true, curveSmoothness: 0.35,
              color: const Color(0xFF0D7377),
              barWidth: 2.5,
              belowBarData: BarAreaData(show: true,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [const Color(0xFF0D7377).withValues(alpha: 0.25), const Color(0xFF0D7377).withValues(alpha: 0.0)])),
              dotData: FlDotData(show: true,
                  getDotPainter: (spot, _, _, _) => FlDotCirclePainter(radius: 3.5,
                      color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF0D7377))),
            )],
          )),
        ),
        if (!hasData)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Les données s\'afficheront au fil des livraisons',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11))),
      ]),
    );
  }

  String _fmtK(double v) {
    if (v == 0) return '0';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  // ── Top Livreurs ────────────────────────────────────────────────────────────
  Widget _topLivreursWidget() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🏆 Top Livreurs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D7377))),
      const SizedBox(height: 12),
      ..._topLivreurs.asMap().entries.take(5).map((e) {
        final i = e.key; final l = e.value;
        final nom      = l['nom'] as String? ?? 'Livreur';
        final nb       = (l['nbLivraisons'] as num?)?.toInt() ?? 0;
        final ca       = (l['ca'] as num?)?.toInt() ?? 0;
        final medals   = ['🥇','🥈','🥉'];
        final medal    = i < medals.length ? medals[i] : '${i+1}.';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: i == 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Text(medal, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('$nb livraisons', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ])),
            Text('${_fmt(ca)} FCFA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: i == 0 ? Colors.orange.shade700 : const Color(0xFF0D7377))),
          ]));
      }),
    ]));

  Widget _ongletComptes() {
    return Column(children: [
      _header('Comptes 👥'),
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['tous','livreur','receptionniste','client','admin'].map((r) =>
          Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(_labelRole(r)), selected: _filtreRole == r,
            selectedColor: const Color(0xFF0D7377).withValues(alpha: 0.15), checkmarkColor: const Color(0xFF0D7377),
            onSelected: (_) { setState(() => _filtreRole = r); _chargerUtilisateurs(role: r == 'tous' ? null : r); }))).toList()))),
      if (_formUserVisible)
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👤 Nouveau compte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D7377))),
            const SizedBox(height: 12),
            _champ(_nomCtrl, 'Nom complet', Icons.person_outlined),   const SizedBox(height: 10),
            _champ(_emailCtrl, 'Email', Icons.email_outlined, clavier: TextInputType.emailAddress), const SizedBox(height: 10),
            _champ(_telCtrl, 'Téléphone', Icons.phone_outlined, clavier: TextInputType.phone), const SizedBox(height: 10),
            _champ(_mdpCtrl, 'Mot de passe', Icons.lock_outlined), const SizedBox(height: 12),
            Row(children: ['livreur','receptionniste','admin'].map((r) => Padding(padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(_labelRole(r)), selected: _roleNouvel == r, selectedColor: const Color(0xFFF97316),
                labelStyle: TextStyle(color: _roleNouvel == r ? Colors.white : Colors.black87),
                onSelected: (_) => setState(() => _roleNouvel = r)))).toList()),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
              onPressed: _creationEnCours ? null : _creerUtilisateur,
              icon: _creationEnCours ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.person_add, size: 18),
              label: const Text('Créer le compte'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ])),
      Expanded(child: _chargementUsers ? const Center(child: CircularProgressIndicator())
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _utilisateurs.length, itemBuilder: (_, i) => _carteUser(_utilisateurs[i]))),
    ]);
  }

  Widget _ongletLivraisons() {
    return Column(children: [
      _header('Livraisons 📦'),
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['tous','en_attente','en_cours','en_livraison','livre','annule'].map((s) =>
          Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(_labelStatut(s)), selected: _filtreStatut == s,
            selectedColor: _couleurStatut(s).withValues(alpha: 0.15), checkmarkColor: _couleurStatut(s),
            onSelected: (_) { setState(() => _filtreStatut = s); _chargerLivraisons(statut: s == 'tous' ? null : s); }))).toList()))),
      Expanded(child: _chargementLivraisons ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _chargerLivraisons, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _toutesLivraisons.length, itemBuilder: (_, i) => _carteLivraison(_toutesLivraisons[i])))),
    ]);
  }

  Widget _ongletTarifs() {
    if (_chargementTarifs) return Column(children: [_header('Tarifs 💰'), const Expanded(child: Center(child: CircularProgressIndicator()))]);
    return Column(children: [_header('Tarifs 💰', action: IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 20), onPressed: _chargerTarifs)),
      Expanded(child: RefreshIndicator(onRefresh: _chargerTarifs, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📦 Catégories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
        const SizedBox(height: 8),
        ..._tarifs.map((t) => _carteTarif(Map<String, dynamic>.from(t as Map))),
        const SizedBox(height: 20),
        const Text('🗺️ Zones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
        const SizedBox(height: 8),
        ..._zones.map((z) => _carteZone(Map<String, dynamic>.from(z as Map))),
      ]))))
    ]);
  }

  // ─── Widgets communs ──────────────────────────────────────────────────────
  Widget _champ(TextEditingController ctrl, String label, IconData icone, {TextInputType clavier = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: clavier, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone, color: const Color(0xFF0D7377), size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D7377), width: 2)), filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));

  Widget _carteCA({required String titre, required dynamic montant, required IconData icone, required Color couleur}) =>
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icone, color: Colors.white70, size: 22), const SizedBox(height: 8),
        Text('${_fmt(montant)} FCFA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(titre, style: const TextStyle(color: Colors.white70, fontSize: 12))]));

  Widget _carteStat(String label, dynamic val, Color c, IconData ic) =>
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(ic, color: c, size: 20)), const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$val', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))])]));

  Widget _carteUser(Map<String, dynamic> user) {
    final actif = user['actif'] as bool; final role = user['role'] as String;
    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: _couleurRole(role).withValues(alpha: 0.15), child: Icon(_iconeRole(role), color: _couleurRole(role), size: 22)),
        title: Row(children: [Expanded(child: Text(user['nom'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _couleurRole(role).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(_labelRole(role), style: TextStyle(color: _couleurRole(role), fontSize: 11, fontWeight: FontWeight.w600)))]),
        subtitle: Text(user['email'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(actif ? Icons.block : Icons.check_circle, color: actif ? Colors.orange : Colors.green, size: 20), onPressed: () => _changerStatut(user['_id'], !actif)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _supprimerUtilisateur(user['_id'], user['nom'])),
        ])));
  }

  Widget _carteLivraison(Map<String, dynamic> liv) {
    final statut = liv['statut'] as String; final c = _couleurStatut(statut); final l = _labelStatut(statut);
    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(l, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12))),
          Text('${_fmt(liv['prix'])} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D7377)))]),
        const SizedBox(height: 8),
        Row(children: [const Icon(Icons.trip_origin, color: Colors.green, size: 14), const SizedBox(width: 6), Expanded(child: Text(liv['adresse_depart'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 4),
        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 14), const SizedBox(width: 6), Expanded(child: Text(liv['adresse_arrivee'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))]),
      ])));
  }

  Widget _carteTarif(Map<String, dynamic> tarif) {
    final surDevis = tarif['sur_devis'] == true;
    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))]),
      child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0D7377).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2, color: Color(0xFF0D7377), size: 22)),
        title: Text(tarif['label'] ?? tarif['categorie'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(surDevis ? 'Sur devis' : '${_fmt(tarif['prix_base'])} FCFA', style: TextStyle(color: surDevis ? Colors.orange : const Color(0xFF0D7377), fontWeight: FontWeight.bold)),
        trailing: IconButton(icon: const Icon(Icons.edit, color: Color(0xFF0D7377)), onPressed: () => _dialogModifierTarif(tarif))));
  }

  Widget _carteZone(Map<String, dynamic> zone) {
    final frais = (zone['frais_supplementaires'] as num?)?.toInt() ?? 0;
    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))]),
      child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.map_outlined, color: Color(0xFFF97316), size: 22)),
        title: Text(zone['nom'] ?? zone['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(zone['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(frais == 0 ? 'Inclus' : '+${_fmt(frais)} FCFA', style: TextStyle(color: frais == 0 ? Colors.green : const Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 13)),
          IconButton(icon: const Icon(Icons.edit, color: Color(0xFFF97316)), onPressed: () => _dialogModifierZone(zone)),
        ])));
  }

  Future<void> _dialogModifierTarif(Map<String, dynamic> tarif) async {
    final prixCtrl = TextEditingController(text: (tarif['prix_base'] ?? 0).toString());
    bool surDevis = tarif['sur_devis'] == true; bool enCours = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text('Modifier — ${tarif['label'] ?? tarif['categorie']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: prixCtrl, keyboardType: TextInputType.number, enabled: !surDevis,
            decoration: InputDecoration(labelText: 'Prix de base (FCFA)', prefixIcon: const Icon(Icons.payments_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixText: 'FCFA')),
        const SizedBox(height: 16),
        Row(children: [Switch(value: surDevis, activeThumbColor: const Color(0xFFF97316), activeTrackColor: const Color(0xFFF97316).withValues(alpha: 0.4), onChanged: (v) => set(() => surDevis = v)), const SizedBox(width: 8), const Expanded(child: Text('Sur devis uniquement'))]),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(onPressed: enCours ? null : () async {
          set(() => enCours = true);
          final nav = Navigator.of(ctx); final msg = ScaffoldMessenger.of(context);
          final r = await ApiService.modifierTarif(categorie: tarif['categorie'], prixBase: double.tryParse(prixCtrl.text) ?? 0, surDevis: surDevis);
          nav.pop();
          if (r['success'] == true) { msg.showSnackBar(const SnackBar(content: Text('✅ Tarif mis à jour !'), backgroundColor: Colors.green)); if (mounted) _chargerTarifs(); }
          else msg.showSnackBar(SnackBar(content: Text(r['message'] ?? 'Erreur'), backgroundColor: Colors.red));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white), child: enCours ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enregistrer')),
      ])));
    prixCtrl.dispose();
  }

  Future<void> _dialogModifierZone(Map<String, dynamic> zone) async {
    final fraisCtrl = TextEditingController(text: (zone['frais_supplementaires'] ?? 0).toString());
    bool enCours = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text('Modifier — ${zone['nom'] ?? zone['code']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
      content: TextField(controller: fraisCtrl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Frais supplémentaires (FCFA)', prefixIcon: const Icon(Icons.add_road), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), helperText: '0 = inclus', suffixText: 'FCFA')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(onPressed: enCours ? null : () async {
          set(() => enCours = true);
          final nav = Navigator.of(ctx); final msg = ScaffoldMessenger.of(context);
          final r = await ApiService.modifierZone(code: zone['code'], fraisSupplementaires: int.tryParse(fraisCtrl.text) ?? 0);
          nav.pop();
          if (r['success'] == true) { msg.showSnackBar(const SnackBar(content: Text('✅ Zone mise à jour !'), backgroundColor: Colors.green)); if (mounted) _chargerTarifs(); }
          else msg.showSnackBar(SnackBar(content: Text(r['message'] ?? 'Erreur'), backgroundColor: Colors.red));
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white), child: enCours ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enregistrer')),
      ])));
    fraisCtrl.dispose();
  }

  String _fmt(dynamic m) { if (m == null) return '0'; final v = (m as num).toInt(); return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (x) => '${x[1]} '); }
  String _labelRole(String r) { switch (r) { case 'tous': return 'Tous'; case 'livreur': return 'Livreur'; case 'receptionniste': return 'Réceptionniste'; case 'client': return 'Client'; case 'admin': return 'Admin'; default: return r; } }
  Color  _couleurRole(String r) { switch (r) { case 'livreur': return const Color(0xFF0D7377); case 'receptionniste': return const Color(0xFFF97316); case 'client': return Colors.blue; case 'admin': return Colors.purple; default: return Colors.grey; } }
  IconData _iconeRole(String r) { switch (r) { case 'livreur': return Icons.delivery_dining; case 'receptionniste': return Icons.headset_mic; case 'client': return Icons.person; case 'admin': return Icons.admin_panel_settings; default: return Icons.person; } }
  Color  _couleurStatut(String s) { switch (s) { case 'tous': return Colors.blueGrey; case 'en_attente': return Colors.orange; case 'en_cours': return const Color(0xFF0D7377); case 'en_livraison': return Colors.purple; case 'livre': return Colors.green; case 'annule': return Colors.red; default: return Colors.grey; } }
  String _labelStatut(String s) { switch (s) { case 'tous': return 'Tous'; case 'en_attente': return '⏳ Attente'; case 'en_cours': return '🔄 En cours'; case 'en_livraison': return '🚚 Livraison'; case 'livre': return '✅ Livré'; case 'annule': return '❌ Annulé'; default: return s; } }
}