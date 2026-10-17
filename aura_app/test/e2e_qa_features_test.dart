import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aura_app/core/services/chat_translation_service.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('E2E QA Verification: In-Chat Real-Time Translation', () {
    test('Language detection and translation fallback engine', () async {
      final service = ChatTranslationService();

      // Test Spanish detection & translation
      final resultEs = await service.translateMessage(
        text: '¡Hola! Me encantaron tus fotos de viajes. ¿Quieres tomar un café? 😊',
        targetLanguage: 'en',
      );

      expect(resultEs.success, isTrue);
      expect(resultEs.detectedLanguage, equals('es'));
      expect(resultEs.targetLanguage, equals('en'));
      expect(resultEs.translatedText.toLowerCase().contains('hello') || resultEs.translatedText.toLowerCase().contains('coffee'), isTrue);

      // Test French detection & translation
      final resultFr = await service.translateMessage(
        text: 'Bonjour, comment vas-tu ?',
        targetLanguage: 'en',
      );
      expect(resultFr.success, isTrue);
      expect(resultFr.detectedLanguage, equals('fr'));

      // Test Hindi detection & translation
      final resultHi = await service.translateMessage(
        text: 'नमस्ते, आप कैसे हैं?',
        targetLanguage: 'en',
      );
      expect(resultHi.success, isTrue);
      expect(resultHi.detectedLanguage, equals('hi'));
    });

    test('ChatMessage model toggles translated and original state in-place', () {
      final msg = ChatMessage(
        id: 'msg_test_001',
        matchId: 'match_123',
        senderId: 'usr_test_maya',
        content: '¡Hola! ¿Cómo estás?',
        sentAt: DateTime.now(),
        isMine: false,
        detectedLanguage: 'Spanish',
        translatedContent: 'Hello! How are you?',
        showTranslated: false,
      );

      expect(msg.showTranslated, isFalse);
      expect(msg.content, equals('¡Hola! ¿Cómo estás?'));

      // Toggle to translated
      msg.showTranslated = true;
      expect(msg.showTranslated, isTrue);
      expect(msg.translatedContent, equals('Hello! How are you?'));

      // Toggle back to original
      msg.showTranslated = false;
      expect(msg.showTranslated, isFalse);
    });
  });

  group('E2E QA Verification: Voice Note Audio Messaging', () {
    test('Voice Note message type instantiation & metadata structure', () {
      final voiceMsg = ChatMessage(
        id: 'vn_001',
        matchId: 'match_123',
        senderId: 'usr_test_alex',
        content: 'Voice Note (0:05)',
        type: MessageType.voiceNote,
        audioDurationSeconds: 5,
        audioWaveform: [0.2, 0.5, 0.8, 0.9, 0.6, 0.3],
        sentAt: DateTime.now(),
        isMine: true,
      );

      expect(voiceMsg.type, equals(MessageType.voiceNote));
      expect(voiceMsg.audioDurationSeconds, equals(5));
      expect(voiceMsg.audioWaveform?.length, equals(6));
      expect(voiceMsg.isMine, isTrue);
    });
  });
}
