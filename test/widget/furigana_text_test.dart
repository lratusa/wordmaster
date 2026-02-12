import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/common_widgets/furigana_text.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('FuriganaText', () {
    testWidgets('displays text only when no reading provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FuriganaText(text: '食べる'),
      ));

      expect(find.text('食べる'), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('displays text only when reading is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FuriganaText(text: '食べる', reading: ''),
      ));

      expect(find.text('食べる'), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('displays text only when reading equals text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FuriganaText(text: 'たべる', reading: 'たべる'),
      ));

      // Should only show one text widget, not two in a column
      expect(find.text('たべる'), findsOneWidget);
    });

    testWidgets('displays both reading and text in column when reading provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FuriganaText(text: '食べる', reading: 'たべる'),
      ));

      expect(find.text('食べる'), findsOneWidget);
      expect(find.text('たべる'), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('reading appears above main text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const FuriganaText(text: '勉強', reading: 'べんきょう'),
      ));

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.children.length, equals(2));

      // First child should be reading, second should be main text
      final readingText = column.children[0] as Text;
      final mainText = column.children[1] as Text;

      expect(readingText.data, equals('べんきょう'));
      expect(mainText.data, equals('勉強'));
    });

    testWidgets('applies custom text styles', (WidgetTester tester) async {
      const customStyle = TextStyle(fontSize: 40, color: Colors.red);
      const customReadingStyle = TextStyle(fontSize: 12, color: Colors.blue);

      await tester.pumpWidget(buildTestWidget(
        const FuriganaText(
          text: '日本語',
          reading: 'にほんご',
          textStyle: customStyle,
          readingStyle: customReadingStyle,
        ),
      ));

      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(textWidgets.length, equals(2));

      expect(textWidgets[0].style?.color, equals(Colors.blue));
      expect(textWidgets[1].style?.fontSize, equals(40));
    });
  });

  group('InlineFurigana', () {
    testWidgets('displays text only when no reading',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const InlineFurigana(text: '本'),
      ));

      expect(find.text('本'), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('displays both reading and text when reading provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const InlineFurigana(text: '本', reading: 'ほん'),
      ));

      expect(find.text('本'), findsOneWidget);
      expect(find.text('ほん'), findsOneWidget);
    });

    testWidgets('applies fontSize correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const InlineFurigana(text: '漢字', reading: 'かんじ', fontSize: 24),
      ));

      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();

      // Main text should have specified fontSize
      expect(textWidgets[1].style?.fontSize, equals(24));
      // Reading should be half the size
      expect(textWidgets[0].style?.fontSize, equals(12));
    });

    testWidgets('applies custom text color', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        const InlineFurigana(
          text: '漢字',
          reading: 'かんじ',
          textColor: Colors.green,
        ),
      ));

      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(textWidgets[1].style?.color, equals(Colors.green));
    });
  });
}
