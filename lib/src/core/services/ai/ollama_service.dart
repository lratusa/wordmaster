import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../features/word_lists/domain/models/word.dart';
import 'ai_service.dart';

/// Ollama local API implementation
class OllamaService extends AiService {
  final String baseUrl;
  final String model;
  late final Dio _dio;

  OllamaService({
    this.baseUrl = 'http://localhost:11434',
    this.model = 'qwen2.5:7b',
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));
  }

  @override
  Future<PassageResult> generatePassage({
    required List<Word> words,
    required String language,
  }) async {
    final prompt = buildPrompt(words, language);

    final response = await _dio.post(
      '/api/chat',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful language teacher. Always respond with valid JSON only.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
        'format': 'json',
      },
    );

    final content =
        response.data['message']['content'] as String;
    final json = jsonDecode(content) as Map<String, dynamic>;
    return PassageResult.fromJson(json);
  }
}
