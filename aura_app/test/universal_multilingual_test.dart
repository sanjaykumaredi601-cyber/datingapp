import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/chat_translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatTranslationService service;

  setUp(() {
    service = ChatTranslationService();
    service.clearCache();
  });

  group('1. Universal Language Coverage & Dynamic BCP-47 Architecture Tests', () {
    test('Registry contains all 22 Eighth Schedule Indian languages', () {
      final eighthScheduleCodes = [
        'hi', 'te', 'bn', 'ta', 'mr', 'gu', 'kn', 'ml', 'pa', 'or',
        'as', 'ur', 'sa', 'mai', 'sat', 'ks', 'ne', 'kok', 'sd', 'doi',
        'mni', 'brx',
      ];

      for (final code in eighthScheduleCodes) {
        final lang = service.getLanguage(code);
        expect(lang.code, equals(code));
        expect(lang.name.isNotEmpty, isTrue, reason: 'Failed for language code $code');
        expect(lang.nativeName.isNotEmpty, isTrue, reason: 'Missing native name for $code');
        expect(lang.region, equals('Indian Eighth Schedule'));
        expect(lang.supportsText, isTrue);
      }
    });

    test('Registry contains high-demand regional spoken dialects', () {
      final regionalDialects = ['bho', 'mwr', 'hne', 'bgc', 'mag'];

      for (final code in regionalDialects) {
        final lang = service.getLanguage(code);
        expect(lang.code, equals(code));
        expect(lang.region, equals('Indian Regional Dialect'));
        expect(lang.supportsText, isTrue);
      }
    });

    test('Registry contains comprehensive global languages across Asia, Middle East, Europe & Americas', () {
      final globalCodes = [
        'tl', 'id', 'ms', 'vi', 'th', 'my', 'ja', 'ko', 'zh', 'yue',
        'ar', 'fa', 'tr', 'ps', 'uz', 'kk',
        'en', 'es', 'fr', 'ru', 'de', 'pt', 'it', 'nl', 'uk', 'pl',
      ];

      for (final code in globalCodes) {
        final lang = service.getLanguage(code);
        expect(lang.code, equals(code));
        expect(lang.region, equals('Global / International'));
      }
    });

    test('Extensibility: Dynamically accepts custom BCP-47 language tags without client app code modification', () {
      // Dynamic variant tag
      final tagVariant = service.getLanguage('es-MX');
      expect(tagVariant.code, equals('es'));
      expect(tagVariant.name, equals('Spanish'));

      // Fully unseen dynamic dynamic BCP-47 tag
      final dynamicTag = service.getLanguage('x-klingon-custom');
      expect(dynamicTag.code, equals('x-klingon-custom'));
      expect(dynamicTag.family, equals('Extensible Dynamic'));
      expect(dynamicTag.supportsText, isTrue);
    });
  });

  group('2. Source Language Auto-Detection & Confidence Scoring', () {
    test('Detects Telugu script correctly with high confidence', () async {
      const text = 'మీతో మాట్లాడటం చాలా సంతోషంగా ఉంది!';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('te'));
      expect((result['confidence'] as num).toDouble(), greaterThanOrEqualTo(0.95));
    });

    test('Detects Tamil script correctly', () async {
      const text = 'உங்களைச் சந்தித்ததில் மிக்க மகிழ்ச்சி!';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('ta'));
      expect((result['confidence'] as num).toDouble(), greaterThanOrEqualTo(0.95));
    });

    test('Detects Bengali script correctly', () async {
      const text = 'আপনার সাথে দেখা করে খুব ভালো লাগল!';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('bn'));
      expect((result['confidence'] as num).toDouble(), greaterThanOrEqualTo(0.95));
    });

    test('Detects Assamese script with distinctive characters', () async {
      const text = 'আপোনাক লগ পাই ভাল লাগিল, কফি খাব নেকি?';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('as'));
    });

    test('Detects Bhojpuri regional dialect in Devanagari', () async {
      const text = 'रउआ से मिल के बहुते खुशी भइल, कहिया फुर्सत बा?';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('bho'));
    });

    test('Detects Ol Chiki script for Santali', () async {
      const text = 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱟᱹᱨᱥᱤ ᱡᱚᱦᱟᱨ';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('sat'));
    });

    test('Detects Russian Cyrillic script', () async {
      const text = 'Привет! Мне очень понравились твои фото из путешествий.';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('ru'));
    });

    test('Detects Tagalog / Filipino Latin dialect', () async {
      const text = 'Kamusta! Nagustuhan ko ang iyong mga larawan sa paglalakbay.';
      final result = await service.detectLanguage(text);
      expect(result['detectedLanguage'], equals('tl'));
    });
  });

  group('3. Automated Cross-Language Translation Matrix Tests', () {
    test('Complex Indic: Telugu to Bengali translation', () async {
      final res = await service.translateMessage(
        text: 'మనం కలిసి కాఫీ తాగుదామా? ☕',
        targetLanguage: 'bn',
        sourceLanguage: 'te',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('bn'));
      expect(res.translatedText.isNotEmpty, isTrue);
      expect(res.confidence, greaterThanOrEqualTo(0.90));
    });

    test('Complex Indic: Marathi to Tamil translation', () async {
      final res = await service.translateMessage(
        text: 'आपण एकत्र कॉफी घेऊया का? ☕',
        targetLanguage: 'ta',
        sourceLanguage: 'mr',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('ta'));
      expect(res.translatedText.isNotEmpty, isTrue);
    });

    test('Complex Indic: Assamese to Hindi translation', () async {
      final res = await service.translateMessage(
        text: 'আমি একেলগে কফি খাবলৈ যাব পাৰোনে? ☕',
        targetLanguage: 'hi',
        sourceLanguage: 'as',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('hi'));
      expect(res.translatedText.isNotEmpty, isTrue);
    });

    test('Regional to Global: Bhojpuri to English translation', () async {
      final res = await service.translateMessage(
        text: 'प्रणाम! रउआ के घूमे-फिरे के फोटो बहुते नीक लागल। कॉफ़ी पियब? 😊',
        targetLanguage: 'en',
        sourceLanguage: 'bho',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('en'));
      expect(res.translatedText.contains('coffee') || res.translatedText.contains('Hello'), isTrue);
    });

    test('Regional to Global: Gujarati to French translation', () async {
      final res = await service.translateMessage(
        text: 'શું આપણે સાથે કૉફી પીવા જઈ શકીએ? ☕',
        targetLanguage: 'fr',
        sourceLanguage: 'gu',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('fr'));
      expect(res.translatedText.contains('café') || res.translatedText.contains('Voulez-vous'), isTrue);
    });

    test('Global Cross-Language: Russian to Hindi translation', () async {
      final res = await service.translateMessage(
        text: 'Привет! Мне очень понравились твои фото из путешествий. Попьем кофе? 😊',
        targetLanguage: 'hi',
        sourceLanguage: 'ru',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('hi'));
      expect(res.translatedText.isNotEmpty, isTrue);
    });

    test('Global Cross-Language: Tagalog to English translation', () async {
      final res = await service.translateMessage(
        text: 'Kamusta! Nagustuhan ko ang iyong mga larawan. Magkape tayo? 😊',
        targetLanguage: 'en',
        sourceLanguage: 'tl',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('en'));
      expect(res.translatedText.isNotEmpty, isTrue);
    });

    test('Global Cross-Language: Arabic to Spanish translation', () async {
      final res = await service.translateMessage(
        text: 'هل ترغب في شرب القهوة معاً؟ ☕',
        targetLanguage: 'es',
        sourceLanguage: 'ar',
      );
      expect(res.success, isTrue);
      expect(res.targetLanguage, equals('es'));
      expect(res.translatedText.contains('café') || res.translatedText.isNotEmpty, isTrue);
    });
  });

  group('4. Performance, Local Caching Layer & Latency Verification', () {
    test('Cache hit returns result under 5ms and flags isFromCache = true', () async {
      const phrase = 'Hello! I loved your travel photos. Do you want to grab a coffee? 😊';

      // First query (warms up the cache)
      final firstResult = await service.translateMessage(
        text: phrase,
        targetLanguage: 'es',
      );
      expect(firstResult.success, isTrue);
      expect(service.cacheSize, equals(1));

      // Second query (must be a cache hit)
      final cachedResult = await service.translateMessage(
        text: phrase,
        targetLanguage: 'es',
      );
      expect(cachedResult.isFromCache, isTrue);
      expect(cachedResult.latencyMs, lessThanOrEqualTo(5), reason: 'Cache hit latency must be <= 5ms');
      expect(cachedResult.translatedText, equals(firstResult.translatedText));
    });
  });

  group('5. Voice Note (Audio) Speech-to-Text (STT) & Translation Pipeline', () {
    test('Transcribes Opus audio note and returns transcription with confidence', () async {
      final sttResult = await service.transcribeVoiceNote(
        audioPathOrContent: 'mock_base64_encoded_audio_opus_chunk_test',
        languageHint: 'bho',
      );

      expect(sttResult.success, isTrue);
      expect(sttResult.transcribedText.isNotEmpty, isTrue);
      expect(sttResult.detectedLanguage, equals('bho'));
      expect(sttResult.confidence, greaterThanOrEqualTo(0.90));
    });

    test('Voice transcript can be seamlessly translated with isVoiceTranscript = true', () async {
      const audioTranscript = 'रउआ से मिल के बहुते खुशी भइल, कहिया फुर्सत बा? ☕';

      final transResult = await service.translateMessage(
        text: audioTranscript,
        targetLanguage: 'en',
        sourceLanguage: 'bho',
        isVoiceTranscript: true,
      );

      expect(transResult.success, isTrue);
      expect(transResult.isVoiceTranscript, isTrue);
      expect(transResult.targetLanguage, equals('en'));
      expect(transResult.translatedText.isNotEmpty, isTrue);
    });
  });
}
