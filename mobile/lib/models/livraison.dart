// ═══════════════════════════════════════════════════════════════════
// MODÈLE LIVRAISON — lib/models/livraison.dart
// Remplace ou crée ce fichier dans ton projet
//
// IMPORTANT: ce modèle stocke le JSON brut dans _raw
// Tous les champs sont lus depuis _raw → zéro crash si un champ manque
// ═══════════════════════════════════════════════════════════════════

class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint({required this.lat, required this.lng});

  factory LatLngPoint.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const LatLngPoint(lat: 0, lng: 0);
    return LatLngPoint(
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Livraison {
  final Map<String, dynamic> _raw;

  Livraison._(this._raw);

  // ── Constructeur depuis JSON ─────────────────────────────────────
  factory Livraison.fromJson(Map<String, dynamic> json) => Livraison._(json);

  // ── Identifiant ──────────────────────────────────────────────────
  String get id => (_raw['_id'] ?? _raw['id'] ?? '').toString();

  // ── Statut ───────────────────────────────────────────────────────
  String get statut => (_raw['statut'] as String?) ?? 'en_attente';

  // ── Adresses ─────────────────────────────────────────────────────
  String get adresseDepart  => (_raw['adresse_depart']  as String?) ?? '';
  String get adresseArrivee => (_raw['adresse_arrivee'] as String?) ?? '';

  // ── Coordonnées ──────────────────────────────────────────────────
  LatLngPoint? get coordonneesDepart =>
      _raw['coordonnees_depart'] is Map
          ? LatLngPoint.fromJson(
              Map<String, dynamic>.from(_raw['coordonnees_depart'] as Map))
          : null;

  LatLngPoint? get coordonneesArrivee =>
      _raw['coordonnees_arrivee'] is Map
          ? LatLngPoint.fromJson(
              Map<String, dynamic>.from(_raw['coordonnees_arrivee'] as Map))
          : null;

  // ── Prix ─────────────────────────────────────────────────────────
  double get prix     => ((_raw['prix']      as num?)?.toDouble()) ?? 0;
  double get prixBase => ((_raw['prix_base'] as num?)?.toDouble()) ?? 0;
  double get fraisZone => ((_raw['frais_zone'] as num?)?.toDouble()) ?? 0;

  // ── Colis ────────────────────────────────────────────────────────
  String get descriptionColis => (_raw['description_colis'] as String?) ?? '';
  String get categorieColis   => (_raw['categorie_colis']   as String?) ?? '';
  String get zone             => (_raw['zone']              as String?) ?? '';

  // ── Paiement ─────────────────────────────────────────────────────
  // Lecture safe depuis _raw → jamais de NoSuchMethodError
  String get modePaiement   => (_raw['mode_paiement']   as String?) ?? 'cash';
  String get statutPaiement => (_raw['statut_paiement'] as String?) ?? 'non_requis';

  // ── Personnes ────────────────────────────────────────────────────
  Map<String, dynamic>? get client =>
      _raw['client'] is Map
          ? Map<String, dynamic>.from(_raw['client'] as Map)
          : null;

  Map<String, dynamic>? get livreur =>
      _raw['livreur'] is Map
          ? Map<String, dynamic>.from(_raw['livreur'] as Map)
          : null;

  // ── Position GPS livreur (temps réel) ────────────────────────────
  LatLngPoint get positionLivreur =>
      _raw['position_livreur'] is Map
          ? LatLngPoint.fromJson(
              Map<String, dynamic>.from(_raw['position_livreur'] as Map))
          : const LatLngPoint(lat: 0, lng: 0);

  // ── Preuves ──────────────────────────────────────────────────────
  Map<String, dynamic>? get preuveLivraison =>
      _raw['preuve_livraison'] is Map
          ? Map<String, dynamic>.from(_raw['preuve_livraison'] as Map)
          : null;

  Map<String, dynamic>? get preuvePaiement =>
      _raw['preuve_paiement'] is Map
          ? Map<String, dynamic>.from(_raw['preuve_paiement'] as Map)
          : null;

  String get statutPreuveLivraison =>
      (_raw['statut_preuve_livraison'] as String?) ?? '';

  // ── Note du client ───────────────────────────────────────────────
  int? get note => (_raw['note'] as num?)?.toInt();

  // ── Date de création ─────────────────────────────────────────────
  DateTime get createdAt {
    final v = _raw['createdAt'] ?? _raw['created_at'];
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  // ── Accès brut (pour les écrans qui travaillent en Map) ──────────
  Map<String, dynamic> get raw => Map<String, dynamic>.from(_raw);

  // ── copyWith (pour mise à jour partielle via socket) ─────────────
  Livraison copyWith({
    String? statut,
    LatLngPoint? positionLivreur,
    String? statutPaiement,
  }) {
    final updated = Map<String, dynamic>.from(_raw);
    if (statut != null)          updated['statut']           = statut;
    if (statutPaiement != null)  updated['statut_paiement']  = statutPaiement;
    if (positionLivreur != null) {
      updated['position_livreur'] = {
        'lat': positionLivreur.lat,
        'lng': positionLivreur.lng,
      };
    }
    return Livraison._(updated);
  }

  @override
  String toString() => 'Livraison(id: $id, statut: $statut, prix: $prix)';
}