class Coordonnees {
  final double lat;
  final double lng;

  Coordonnees({required this.lat, required this.lng});

  factory Coordonnees.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return Coordonnees(lat: 0, lng: 0);
    }
    return Coordonnees(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }
}

class Livraison {
  final String               id;
  final String               adresseDepart;
  final String               adresseArrivee;
  final String               statut;
  final double               prix;
  final String               descriptionColis;
  final Coordonnees          coordonneesDepart;
  final Coordonnees          coordonneesArrivee;
  Coordonnees                positionLivreur;
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? livreur;
  final DateTime             createdAt;

  Livraison({
    required this.id,
    required this.adresseDepart,
    required this.adresseArrivee,
    required this.statut,
    required this.prix,
    required this.descriptionColis,
    required this.coordonneesDepart,
    required this.coordonneesArrivee,
    required this.positionLivreur,
    this.client,
    this.livreur,
    required this.createdAt,
  });

  factory Livraison.fromJson(Map<String, dynamic> json) {
    // ✅ client peut être un String (ID) ou un Map (populé) ou null
    Map<String, dynamic>? clientMap;
    final clientRaw = json['client'];
    if (clientRaw is Map<String, dynamic>) {
      clientMap = clientRaw;
    } else if (clientRaw is Map) {
      clientMap = Map<String, dynamic>.from(clientRaw);
    }
    // Si c'est un String (ID non populé) → on ignore, clientMap reste null

    // ✅ Même chose pour livreur
    Map<String, dynamic>? livreurMap;
    final livreurRaw = json['livreur'];
    if (livreurRaw is Map<String, dynamic>) {
      livreurMap = livreurRaw;
    } else if (livreurRaw is Map) {
      livreurMap = Map<String, dynamic>.from(livreurRaw);
    }

    return Livraison(
      id:                 json['_id']              ?? '',
      adresseDepart:      json['adresse_depart']   ?? '',
      adresseArrivee:     json['adresse_arrivee']  ?? '',
      statut:             json['statut']           ?? 'en_attente',
      prix:               (json['prix']            ?? 0).toDouble(),
      descriptionColis:   json['description_colis'] ?? '',
      coordonneesDepart:  Coordonnees.fromJson(json['coordonnees_depart']),
      coordonneesArrivee: Coordonnees.fromJson(json['coordonnees_arrivee']),
      positionLivreur:    Coordonnees.fromJson(json['position_livreur']),
      client:             clientMap,
      livreur:            livreurMap,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Livraison copyWith({Coordonnees? positionLivreur, String? statut}) {
    return Livraison(
      id:                 id,
      adresseDepart:      adresseDepart,
      adresseArrivee:     adresseArrivee,
      statut:             statut             ?? this.statut,
      prix:               prix,
      descriptionColis:   descriptionColis,
      coordonneesDepart:  coordonneesDepart,
      coordonneesArrivee: coordonneesArrivee,
      positionLivreur:    positionLivreur    ?? this.positionLivreur,
      client:             client,
      livreur:            livreur,
      createdAt:          createdAt,
    );
  }
}