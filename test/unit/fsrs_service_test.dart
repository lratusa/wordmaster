import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart';
import 'package:wordmaster/src/features/study/domain/services/fsrs_service.dart';

void main() {
  group('FsrsService', () {
    late FsrsService fsrsService;

    setUp(() {
      fsrsService = FsrsService(desiredRetention: 0.9);
    });

    group('createNewCard', () {
      test('creates card with given wordId', () {
        final card = FsrsService.createNewCard(123);

        expect(card.cardId, equals(123));
        expect(card.state, equals(State.learning));
      });

      test('creates card with due date set to now (UTC)', () {
        final before = DateTime.now().toUtc();
        final card = FsrsService.createNewCard(1);
        final after = DateTime.now().toUtc();

        expect(card.due.isAfter(before.subtract(const Duration(seconds: 1))),
            isTrue);
        expect(card.due.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });
    });

    group('review', () {
      test('returns updated card and review log', () {
        final card = FsrsService.createNewCard(1);
        final result = fsrsService.review(card, Rating.good);

        expect(result.card, isNotNull);
        expect(result.reviewLog, isNotNull);
        expect(result.reviewLog.cardId, equals(1));
        expect(result.reviewLog.rating, equals(Rating.good));
      });

      test('card due date advances after good rating', () {
        final card = FsrsService.createNewCard(1);
        final result = fsrsService.review(card, Rating.good);

        expect(result.card.due.isAfter(card.due), isTrue);
      });

      test('again rating keeps card in learning state', () {
        final card = FsrsService.createNewCard(1);
        final result = fsrsService.review(card, Rating.again);

        expect(result.card.state, equals(State.learning));
      });
    });

    group('getRetrievability', () {
      test('returns a value between 0 and 1', () {
        final card = FsrsService.createNewCard(1);
        final result = fsrsService.review(card, Rating.good);
        final retrievability = fsrsService.getRetrievability(result.card);

        expect(retrievability, greaterThanOrEqualTo(0.0));
        expect(retrievability, lessThanOrEqualTo(1.0));
      });
    });

    group('serialization', () {
      test('cardToJson and cardFromJson are symmetric', () {
        final original = FsrsService.createNewCard(42);
        final json = FsrsService.cardToJson(original);
        final restored = FsrsService.cardFromJson(json);

        expect(restored.cardId, equals(original.cardId));
        expect(restored.state, equals(original.state));
      });

      test('reviewed card survives serialization', () {
        final card = FsrsService.createNewCard(99);
        final reviewed = fsrsService.review(card, Rating.good).card;
        final json = FsrsService.cardToJson(reviewed);
        final restored = FsrsService.cardFromJson(json);

        expect(restored.cardId, equals(99));
        expect(restored.stability, equals(reviewed.stability));
        expect(restored.difficulty, equals(reviewed.difficulty));
      });
    });

    group('intToRating', () {
      test('converts 1 to Rating.again', () {
        expect(FsrsService.intToRating(1), equals(Rating.again));
      });

      test('converts 2 to Rating.hard', () {
        expect(FsrsService.intToRating(2), equals(Rating.hard));
      });

      test('converts 3 to Rating.good', () {
        expect(FsrsService.intToRating(3), equals(Rating.good));
      });

      test('converts 4 to Rating.easy', () {
        expect(FsrsService.intToRating(4), equals(Rating.easy));
      });
    });
  });
}
