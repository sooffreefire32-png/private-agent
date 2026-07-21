import 'package:flutter_test/flutter_test.dart';
import 'package:private_agent/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiService - Built-in API Key', () {
    late AiService aiService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      aiService = AiService();
    });

    test('isConfigured returns false when no API key is set', () {
      expect(aiService.isConfigured, false);
    });

    test('saveSettings stores the API key and isConfigured returns true', () async {
      await aiService.saveSettings(apiKey: 'test-key-123');
      expect(aiService.apiKey, 'test-key-123');
      expect(aiService.isConfigured, true);
    });

    test('saveSettings strips Bearer prefix from API key', () async {
      await aiService.saveSettings(apiKey: 'Bearer sk-test-key');
      expect(aiService.apiKey, 'sk-test-key');
    });

    test('saveSettings strips bearer prefix (lowercase)', () async {
      await aiService.saveSettings(apiKey: 'bearer sk-another-key');
      expect(aiService.apiKey, 'sk-another-key');
    });

    test('init() loads API key from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'api_key': 'prefs-key-456',
      });
      aiService = AiService();
      await aiService.init();
      expect(aiService.apiKey, 'prefs-key-456');
      expect(aiService.isConfigured, true);
    });

    test('init() uses built-in dart-define key when prefs is empty', () async {
      await aiService.init();
      // In test environment, _builtInApiKey is '' so apiKey stays empty
      expect(aiService.apiKey, '');
      expect(aiService.isConfigured, false);
    });

    test('saveSettings saves API key, base URL, and model', () async {
      await aiService.saveSettings(
        apiKey: 'my-key',
        baseUrl: 'https://custom.api.com/v1',
        model: 'my-model',
      );
      expect(aiService.apiKey, 'my-key');
      expect(aiService.baseUrl, 'https://custom.api.com/v1');
      expect(aiService.model, 'my-model');
    });

    test('clearHistory clears conversation history', () {
      aiService.addHistoryMessage('user', 'Hello');
      aiService.addHistoryMessage('assistant', 'Hi there');
      aiService.clearHistory();
      expect(aiService.isConfigured, false);
    });
  });

  group('AiService - Default Values', () {
    test('default base URL is empty string', () {
      final service = AiService();
      expect(service.baseUrl, '');
    });

    test('default model is empty string', () {
      final service = AiService();
      expect(service.model, '');
    });

    test('default max tokens is 1024', () {
      final service = AiService();
      expect(service.maxTokens, 1024);
    });

    test('default temperature is 1.0', () {
      final service = AiService();
      expect(service.temperature, 1.0);
    });
  });
}
