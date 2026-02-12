import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/word_list_repository.dart';
import '../data/repositories/word_repository.dart';
import '../domain/enums/language.dart';
import '../domain/models/word.dart';
import '../domain/models/word_list.dart';

// Repository providers
final wordListRepositoryProvider = Provider<WordListRepository>((ref) {
  return WordListRepository();
});

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  return WordRepository();
});

// All word lists (auto-refreshable)
final allWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final repo = ref.watch(wordListRepositoryProvider);
  return repo.getAllWordLists();
});

// Word lists filtered by language
final wordListsByLanguageProvider =
    FutureProvider.family<List<WordList>, Language>((ref, language) async {
  final repo = ref.watch(wordListRepositoryProvider);
  return repo.getWordListsByLanguage(language);
});

// Single word list by ID
final wordListByIdProvider =
    FutureProvider.family<WordList?, int>((ref, id) async {
  final repo = ref.watch(wordListRepositoryProvider);
  return repo.getWordListById(id);
});

// Words in a word list
final wordsInListProvider =
    FutureProvider.family<List<Word>, int>((ref, wordListId) async {
  final repo = ref.watch(wordRepositoryProvider);
  return repo.getWordsByListId(wordListId);
});

// Search words - using Notifier since StateProvider was removed in Riverpod 3.x
class WordSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final wordSearchQueryProvider =
    NotifierProvider<WordSearchQueryNotifier, String>(
        WordSearchQueryNotifier.new);

final wordSearchResultsProvider = FutureProvider<List<Word>>((ref) async {
  final query = ref.watch(wordSearchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(wordRepositoryProvider);
  return repo.searchWords(query);
});

// Import notifier for loading built-in word lists
final importBuiltInWordListsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(wordListRepositoryProvider);
  return repo.importBuiltInWordLists();
});
