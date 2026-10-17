import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Principal Mobile Security: Secret Code Hidden Chat Vault Service
/// Implements WhatsApp-style stealth architecture:
/// - SHA-256 hashed secret code persistence
/// - Filtered inbox feeds with zero UI indication of locked chats
/// - Real-time stealth search query verification
/// - Auto-purge on background / inactive lifecycle transition
class SecretVaultService extends ChangeNotifier with WidgetsBindingObserver {
  static final SecretVaultService _instance = SecretVaultService._internal();
  factory SecretVaultService({FlutterSecureStorage? storage}) {
    if (storage != null) {
      _instance._storage = storage;
    }
    return _instance;
  }

  SecretVaultService._internal() {
    // Automatically register for app lifecycle state changes
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In headless test environments, WidgetsBinding might not be initialized
    }
  }

  FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _kSecretCodeHashKey = 'app_chat_secret_code_hash';
  static const String _kHiddenConvIdsKey = 'hidden_conversation_ids';

  // In-memory cache for ultra-fast, synchronous UI checks
  final Set<String> _hiddenConversationIds = <String>{};
  String? _cachedSecretCodeHash;
  bool _isUnlocked = false;
  bool _isInitialized = false;

  // Fallback map for test environments where native secure storage is absent
  final Map<String, String> _inMemoryStorageFallback = {};

  /// Current in-memory list of hidden conversation IDs
  List<String> get hiddenConversationIds => List.unmodifiable(_hiddenConversationIds);

  /// Current memory state of vault unlock
  bool get isUnlocked => _isUnlocked;

  /// Check whether the service has initialized its in-memory cache
  bool get isInitialized => _isInitialized;

  /// Initializes the in-memory cache from secure storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _cachedSecretCodeHash = await _readSecure(_kSecretCodeHashKey);
      final rawHiddenList = await _readSecure(_kHiddenConvIdsKey);
      if (rawHiddenList != null && rawHiddenList.isNotEmpty) {
        final decoded = jsonDecode(rawHiddenList);
        if (decoded is List) {
          _hiddenConversationIds.clear();
          _hiddenConversationIds.addAll(decoded.map((e) => e.toString()));
        }
      }
    } catch (e) {
      debugPrint('[SecretVaultService] Storage initialization notice: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Hashes and securely stores the secret code using SHA-256
  Future<void> setSecretCode(String rawCode) async {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Secret code cannot be empty');
    }

    final hash = _sha256Hash(trimmed);
    await _writeSecure(_kSecretCodeHashKey, hash);
    _cachedSecretCodeHash = hash;
    notifyListeners();
  }

  /// Verifies input code against the SHA-256 hash.
  /// If matching, automatically marks vault as unlocked in memory and notifies listeners.
  Future<bool> verifySecretCode(String inputCode) async {
    final trimmed = inputCode.trim();
    if (trimmed.isEmpty) return false;

    final storedHash = await _getOrFetchHash();
    if (storedHash == null || storedHash.isEmpty) return false;

    final inputHash = _sha256Hash(trimmed);
    final isMatch = (inputHash.toLowerCase() == storedHash.toLowerCase());

    if (isMatch) {
      _isUnlocked = true;
      notifyListeners();
    }

    return isMatch;
  }

  /// Checks if a secret code has been configured
  Future<bool> hasSecretCodeConfigured() async {
    final hash = await _getOrFetchHash();
    return hash != null && hash.isNotEmpty;
  }

  /// Synchronous helper to check if a secret code is already cached in memory
  bool hasSecretCodeConfiguredSync() {
    return _cachedSecretCodeHash != null && _cachedSecretCodeHash!.isNotEmpty;
  }

  /// Adds a list of conversation IDs to the vault and persists them securely
  Future<void> addConversationsToVault(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    if (!_isInitialized) await initialize();

    _hiddenConversationIds.addAll(conversationIds);
    await _persistHiddenList();
    notifyListeners();
  }

  /// Removes a single conversation ID from the vault and persists the updated list
  Future<void> removeConversationFromVault(String conversationId) async {
    if (!_isInitialized) await initialize();

    if (_hiddenConversationIds.remove(conversationId)) {
      await _persistHiddenList();
      notifyListeners();
    }
  }

  /// Synchronous check if a conversation ID is hidden (used in inbox feed filtering)
  bool isConversationHidden(String conversationId) {
    return _hiddenConversationIds.contains(conversationId);
  }

  /// Manually locks the vault and purges active unlocked state from memory
  void purgeMemoryUnlockState() {
    if (_isUnlocked) {
      _isUnlocked = false;
      notifyListeners();
      debugPrint('[SecretVaultService] Purged unlocked vault state from memory.');
    }
  }

  /// Clears entire vault configuration (for testing or profile reset)
  Future<void> resetVault() async {
    _hiddenConversationIds.clear();
    _cachedSecretCodeHash = null;
    _isUnlocked = false;
    await _deleteSecure(_kSecretCodeHashKey);
    await _deleteSecure(_kHiddenConvIdsKey);
    notifyListeners();
  }

  // --- Internal Helpers ---

  String _sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String?> _getOrFetchHash() async {
    if (_cachedSecretCodeHash != null) return _cachedSecretCodeHash;
    _cachedSecretCodeHash = await _readSecure(_kSecretCodeHashKey);
    return _cachedSecretCodeHash;
  }

  Future<void> _persistHiddenList() async {
    final encoded = jsonEncode(_hiddenConversationIds.toList());
    await _writeSecure(_kHiddenConvIdsKey, encoded);
  }

  Future<String?> _readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return _inMemoryStorageFallback[key];
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    _inMemoryStorageFallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecretVaultService] Platform secure storage write notice: $e');
    }
  }

  Future<void> _deleteSecure(String key) async {
    _inMemoryStorageFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  // --- AppLifecycleState Auto-Purge ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      purgeMemoryUnlockState();
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }
}
