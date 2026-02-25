class User {
  final String id;
  final String nom;
  final String email;
  final String role;
  final String telephone;
  final String? photoBase64;

  User({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    required this.telephone,
    this.photoBase64,
  });

  // Créer un User depuis un JSON (réponse de l'API)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id:        json['id'] ?? json['_id'] ?? '',
      nom:       json['nom'] ?? '',
      email:     json['email'] ?? '',
      role:      json['role'] ?? 'client',
      telephone: json['telephone'] ?? '',
      photoBase64: json['photo_base64'] as String?,
    );
  }

  // Convertir un User en JSON
  Map<String, dynamic> toJson() {
    return {
      'id':        id,
      'nom':       nom,
      'email':     email,
      'role':      role,
      'telephone': telephone,
    };
  }
}