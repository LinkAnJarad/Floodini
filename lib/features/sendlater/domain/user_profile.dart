class EmergencyContact {
  const EmergencyContact({required this.name, required this.number});

  final String name;
  final String number;

  Map<String, Object?> toJson() => {'name': name, 'number': number};

  factory EmergencyContact.fromJson(Map<String, Object?> json) =>
      EmergencyContact(
        name: json['name'] as String? ?? '',
        number: json['number'] as String? ?? '',
      );
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.contacts,
    required this.disclaimerAccepted,
  });

  final String name;
  final List<EmergencyContact> contacts;
  final bool disclaimerAccepted;

  bool get isComplete =>
      name.trim().isNotEmpty && contacts.isNotEmpty && disclaimerAccepted;

  Map<String, Object?> toJson() => {
    'name': name,
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'disclaimerAccepted': disclaimerAccepted,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    name: json['name'] as String? ?? '',
    contacts: [
      for (final raw in (json['contacts'] as List? ?? const []))
        EmergencyContact.fromJson(Map<String, Object?>.from(raw as Map)),
    ],
    disclaimerAccepted: json['disclaimerAccepted'] as bool? ?? false,
  );
}

/// Strips spaces, dashes, dots and brackets. Returns null unless the result is
/// 7–15 digits with an optional leading '+'.
String? normalizePhoneNumber(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-().]'), '');
  return RegExp(r'^\+?\d{7,15}$').hasMatch(cleaned) ? cleaned : null;
}
