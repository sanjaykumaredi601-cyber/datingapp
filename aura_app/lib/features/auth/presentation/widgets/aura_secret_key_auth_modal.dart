import '../../data/repositories/auth_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/aura_crypto_key_service.dart';

/// Modal dialog / bottom sheet allowing zero-trust authentication via
/// 12-Word Mnemonic Phrase or Hex Private Key.
class AuraSecretKeyAuthModal extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuraSecretKeyAuthModal({
    super.key,
    required this.onAuthenticated,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onAuthenticated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuraSecretKeyAuthModal(onAuthenticated: onAuthenticated),
    );
  }

  @override
  State<AuraSecretKeyAuthModal> createState() => _AuraSecretKeyAuthModalState();
}

class _AuraSecretKeyAuthModalState extends State<AuraSecretKeyAuthModal> {
  final TextEditingController _keyController = TextEditingController();
  bool _isValid = false;
  bool _isGenerating = false;
  String? _generatedAddress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _keyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _keyController.removeListener(_onTextChanged);
    _keyController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _keyController.text.trim();
    final valid = AuraCryptoKeyService.instance.validateMnemonic(text);
    setState(() {
      _isValid = valid;
      _errorMessage = text.isNotEmpty && !valid && text.split(RegExp(r'\s+')).length >= 12
          ? 'Invalid BIP-39 phrase or recognized hex key'
          : null;
      if (valid) {
        _generatedAddress = AuraCryptoKeyService.instance.deriveSovereignAddress(text);
      } else {
        _generatedAddress = null;
      }
    });
  }

  void _generateNewKey() {
    HapticFeedback.mediumImpact();
    setState(() => _isGenerating = true);
    final mnemonic = AuraCryptoKeyService.instance.generate12WordMnemonic();
    _keyController.text = mnemonic;
    setState(() => _isGenerating = false);
  }

  void _copyBackupJson() {
    if (!_isValid) return;
    HapticFeedback.lightImpact();
    final jsonBackup = AuraCryptoKeyService.instance.generateIdentityBackupJson(
      phrase: _keyController.text.trim(),
      uid: 'aur_${DateTime.now().millisecondsSinceEpoch}',
      handle: '@aura.sovereign_${_generatedAddress?.substring(2, 6) ?? "key"}',
    );
    Clipboard.setData(ClipboardData(text: jsonBackup));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF131924),
        content: Text(
          'Encrypted identity backup (aura-identity.json) copied to clipboard!',
          style: TextStyle(color: Color(0xFF67E8F9), fontSize: 12),
        ),
      ),
    );
  }

  bool _isAuthenticating = false;

  Future<void> _submitAuthentication() async {
    if (!_isValid || _isAuthenticating) return;
    HapticFeedback.heavyImpact();
    setState(() => _isAuthenticating = true);

    try {
      final authRepo = AuthRepositoryImpl();
      await authRepo.signInWithSecretKey(_keyController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Authentication error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xFFFFE4E6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7928CA).withValues(alpha: 0.12),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7928CA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7928CA).withValues(alpha: 0.25)),
                  ),
                  child: const Text('🔐', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aura Sovereign Key Authentication',
                        style: TextStyle(
                          color: Color(0xFF181829),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Zero-trust verification via 12-word seed phrase or hex key',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Key Input Area
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isValid
                      ? const Color(0xFF10B981)
                      : (_errorMessage != null ? const Color(0xFFFF4D67) : const Color(0xFFE5E7EB)),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _keyController,
                    maxLines: 3,
                    style: const TextStyle(
                      color: Color(0xFF181829),
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter 12-word recovery mnemonic (e.g. abandon ability able about...) or 0x64-hex key',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                  if (_generatedAddress != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          'Sovereign Identity: $_generatedAddress',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF4D67), fontSize: 11),
              ),
            ],

            const SizedBox(height: 14),

            // Action row: Generate New Key & Backup Download
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _generateNewKey,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Generate Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isValid ? _copyBackupJson : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: BorderSide(
                        color: _isValid
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFE5E7EB),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Backup JSON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isValid ? _submitAuthentication : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                disabledBackgroundColor: const Color(0xFFFF3366).withValues(alpha: 0.25),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: _isValid ? 4 : 0,
              ),
              child: const Text(
                'Authenticate & Connect Frequency',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
