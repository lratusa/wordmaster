import 'dart:convert';

import 'package:fsrs/fsrs.dart';

/// Wraps the FSRS 2.0 algorithm for spaced repetition scheduling.
class FsrsService {
  late final Scheduler _scheduler;

  FsrsService({double desiredRetention = 0.9}) {
    _scheduler = Scheduler(
      parameters: defaultParameters,
      desiredRetention: desiredRetention,
      learningSteps: const [
        Duration(minutes: 1),
        Duration(minutes: 10),
      ],
      relearningSteps: const [
        Duration(minutes: 10),
      ],
      maximumInterval: 36500,
      enableFuzzing: true,
    );
  }

  /// Create a new FSRS card for a word being learned for the first time.
  static Card createNewCard(int wordId) {
    return Card(
      cardId: wordId,
      due: DateTime.now().toUtc(),
    );
  }

  /// Process a review rating and return the updated card and review log.
  ({Card card, ReviewLog reviewLog}) review(Card card, Rating rating) {
    return _scheduler.reviewCard(
      card,
      rating,
      reviewDateTime: DateTime.now().toUtc(),
    );
  }

  /// Get the card's current retrievability (probability of recall).
  double getRetrievability(Card card) {
    return _scheduler.getCardRetrievability(card);
  }

  /// Serialize a card to JSON string for database storage.
  static String cardToJson(Card card) {
    return jsonEncode(card.toMap());
  }

  /// Deserialize a card from JSON string.
  static Card cardFromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return Card.fromMap(map);
  }

  /// Serialize a review log to JSON string.
  static String reviewLogToJson(ReviewLog log) {
    return jsonEncode(log.toMap());
  }

  /// Convert our 1-4 int rating to FSRS Rating enum.
  static Rating intToRating(int rating) {
    return Rating.fromValue(rating);
  }
}
