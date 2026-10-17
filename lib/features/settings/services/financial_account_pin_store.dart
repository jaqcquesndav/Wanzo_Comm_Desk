import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Code PIN d'un compte Mobile Money : conservé sur ce poste seulement.
///
/// Le PIN ne part jamais au serveur ni dans la base locale Hive (il y était
/// en clair, préfixé « encrypted_ »). On garde ici une empreinte salée par
/// compte dans le coffre du système (DPAPI sous Windows), ce qui suffit à
/// vérifier une saisie sans pouvoir relire le code.
class FinancialAccountPinStore {
  static const _prefix = 'financial_account_pin_';

  final FlutterSecureStorage _storage;

  FinancialAccountPinStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Empreinte d'un PIN pour un compte (le compte sert de sel).
  static String fingerprint(String accountId, String pin) =>
      sha256.convert(utf8.encode('$accountId:$pin')).toString();

  /// Enregistre (ou remplace) le PIN du compte. Un PIN vide ne change rien.
  Future<void> save(String accountId, String pin) async {
    final trimmed = pin.trim();
    if (accountId.isEmpty || trimmed.isEmpty) return;
    try {
      await _storage.write(
        key: '$_prefix$accountId',
        value: fingerprint(accountId, trimmed),
      );
    } catch (e) {
      debugPrint('FinancialAccountPinStore: PIN non enregistré ($e)');
    }
  }

  /// Vrai si [pin] correspond au PIN enregistré pour ce compte.
  Future<bool> verify(String accountId, String pin) async {
    try {
      final stored = await _storage.read(key: '$_prefix$accountId');
      return stored != null && stored == fingerprint(accountId, pin.trim());
    } catch (_) {
      return false;
    }
  }

  /// Oublie le PIN du compte (compte supprimé).
  Future<void> remove(String accountId) async {
    try {
      await _storage.delete(key: '$_prefix$accountId');
    } catch (_) {}
  }
}
