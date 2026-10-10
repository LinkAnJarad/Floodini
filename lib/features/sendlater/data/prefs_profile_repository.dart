import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class PrefsProfileRepository implements ProfileRepository {
  const PrefsProfileRepository();

  static const _key = 'user_profile';

  @override
  Future<UserProfile?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(UserProfile profile) async {
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(profile.toJson()),
    );
  }
}
