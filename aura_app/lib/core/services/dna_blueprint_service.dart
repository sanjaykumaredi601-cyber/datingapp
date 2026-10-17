import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aura_app/features/radar/data/models/dna_blueprint_model.dart';

/// Centralized state management, local secure caching, and Firestore synchronization
/// for Aura DNA Compatibility Blueprints.
class DnaBlueprintService extends ChangeNotifier {
  static final DnaBlueprintService _instance = DnaBlueprintService._internal();
  factory DnaBlueprintService() => _instance;

  DnaBlueprintService._internal() {
    _initFuture = _initialize();
  }

  static const String _storageKeyBlueprint = 'aura_user_dna_blueprint';
  static const String _storageKeyHideCutoff = 'aura_radar_hide_below_cutoff';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final Future<void> _initFuture;

  DnaBlueprint _currentBlueprint = DnaBlueprint.defaultUser();
  bool _hideBelowCutoff = false;
  bool _isInitialized = false;

  DnaBlueprint get blueprint => _currentBlueprint;
  bool get hideBelowCutoff => _hideBelowCutoff;
  bool get isInitialized => _isInitialized;
  Future<void> get ready => _initFuture;

  static FirebaseFirestore? _safeFirestore() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[DnaBlueprintService] FirebaseFirestore not available: $e');
      return null;
    }
  }

  static FirebaseAuth? _safeAuth() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('[DnaBlueprintService] FirebaseAuth not available: $e');
      return null;
    }
  }

  Future<void> _initialize() async {
    try {
      // 1. Read locally cached blueprint
      final localJson = await _secureStorage.read(key: _storageKeyBlueprint);
      if (localJson != null && localJson.isNotEmpty) {
        _currentBlueprint = DnaBlueprint.fromJson(localJson);
        debugPrint('[DnaBlueprintService] Loaded local blueprint: $_currentBlueprint');
      }

      // 2. Read cutoff visibility preference
      final hideCutoffVal = await _secureStorage.read(key: _storageKeyHideCutoff);
      if (hideCutoffVal != null) {
        _hideBelowCutoff = hideCutoffVal == 'true';
      }

      _isInitialized = true;
      notifyListeners();

      // 3. Background sync with Cloud Firestore (/users/{uid}/blueprint)
      _syncFromFirestore();
    } catch (e) {
      debugPrint('[DnaBlueprintService] Initialization exception: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _syncFromFirestore() async {
    try {
      final auth = _safeAuth();
      final firestore = _safeFirestore();
      final uid = auth?.currentUser?.uid;
      if (uid == null || firestore == null) return;

      final doc = await firestore.collection('users').doc(uid).collection('settings').doc('blueprint').get();
      if (doc.exists && doc.data() != null) {
        final remoteBlueprint = DnaBlueprint.fromMap(doc.data()!);
        _currentBlueprint = remoteBlueprint;
        await _secureStorage.write(key: _storageKeyBlueprint, value: remoteBlueprint.toJson());
        notifyListeners();
        debugPrint('[DnaBlueprintService] Synced blueprint from Firestore');
      }
    } catch (e) {
      debugPrint('[DnaBlueprintService] Cloud sync error: $e');
    }
  }

  /// Persists blueprint locally to Secure Storage and synchronizes with Firestore `/users/{uid}/blueprint`.
  Future<void> saveBlueprint(DnaBlueprint newBlueprint) async {
    _currentBlueprint = newBlueprint.copyWith(updatedAt: DateTime.now());
    notifyListeners();

    try {
      // 1. Local hardware-backed secure storage
      await _secureStorage.write(
        key: _storageKeyBlueprint,
        value: _currentBlueprint.toJson(),
      );
      debugPrint('[DnaBlueprintService] Persisted blueprint locally');
    } catch (e) {
      debugPrint('[DnaBlueprintService] Local storage write error: $e');
    }

    try {
      // 2. Cloud Firestore sync
      final auth = _safeAuth();
      final firestore = _safeFirestore();
      final uid = auth?.currentUser?.uid ?? 'guest_user';
      if (firestore != null) {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('blueprint')
            .set(_currentBlueprint.toMap(), SetOptions(merge: true))
            .timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => debugPrint(
                  '[DnaBlueprintService] Firestore write timed out (persisted locally)'),
            );
        debugPrint('[DnaBlueprintService] Synced blueprint to Firestore /users/$uid/settings/blueprint');
      }
    } catch (e) {
      debugPrint('[DnaBlueprintService] Firestore write error: $e');
    }
  }

  /// Sets whether nodes below the compatibility cutoff should be completely hidden or dimmed
  Future<void> setHideBelowCutoff(bool hide) async {
    _hideBelowCutoff = hide;
    notifyListeners();

    try {
      await _secureStorage.write(
        key: _storageKeyHideCutoff,
        value: hide.toString(),
      );
    } catch (e) {
      debugPrint('[DnaBlueprintService] Write cutoff pref error: $e');
    }
  }

  /// Calculates dynamic compatibility between the user's current blueprint and a target profile
  int calculateMatch(DnaBlueprint target) {
    return calculateCompatibility(_currentBlueprint, target);
  }

  /// Reset to defaults (for unit tests / session clear)
  @visibleForTesting
  void resetForTesting({DnaBlueprint? blueprint, bool hideBelowCutoff = false}) {
    _currentBlueprint = blueprint ?? DnaBlueprint.defaultUser();
    _hideBelowCutoff = hideBelowCutoff;
    notifyListeners();
  }
}
