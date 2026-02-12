import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../features/word_lists/domain/models/word.dart';
import 'ai_service.dart';

/// OpenAI API implementation
class OpenAiService extends AiService {
  final String apiKey;
  final String model;
  final String baseUrl;
  late final Dio _dio;

  OpenAiService({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1',
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  @override
  Future<PassageResult> generatePassage({
    required List<Word> words,
    required String language,
  }) async {
    final prompt = buildPrompt(words, language);

    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful language teacher. Always respond with valid JSON only.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'response_format': {'type': 'json_object'},
      },
    );

    final content =
        response.data['choices'][0]['message']['content'] as String;
    final json = jsonDecode(content) as Map<String, dynamic>;
    return PassageResult.fromJson(json);
  }
}
