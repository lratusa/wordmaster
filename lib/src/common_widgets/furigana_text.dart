import 'package:flutter/material.dart';

/// Displays Japanese text with furigana (reading) above kanji.
/// Takes the main text (kanji) and reading (hiragana) and renders them stacked.
class FuriganaText extends StatelessWidget {
  final String text;
  final String? reading;
  final TextStyle? textStyle;
  final TextStyle? readingStyle;
  final MainAxisAlignment alignment;

  const FuriganaText({
    super.key,
    required this.text,
    this.reading,
    this.textStyle,
    this.readingStyle,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If no reading or reading equals text, just show the text
    if (reading == null || reading!.isEmpty || reading == text) {
      return Text(
        text,
        style: textStyle ?? theme.textTheme.headlineMedium,
      );
    }

    final mainStyle = textStyle ?? theme.textTheme.headlineMedium;
    final rubyStyle = readingStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: (mainStyle?.fontSize ?? 28) * 0.45,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Text(
          reading!,
          style: rubyStyle,
        ),
        Text(
          text,
          style: mainStyle,
        ),
      ],
    );
  }
}

/// A widget that displays a Japanese word with inline furigana annotation.
/// Shows reading above kanji characters in a compact inline format.
class InlineFurigana extends StatelessWidget {
  final String text;
  final String? reading;
  final double fontSize;
  final Color? textColor;

  const InlineFurigana({
    super.key,
    required this.text,
    this.reading,
    this.fontSize = 16,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (reading == null || reading!.isEmpty || reading == text) {
      return Text(
        text,
        style: TextStyle(fontSize: fontSize, color: textColor),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          reading!,
          style: TextStyle(
            fontSize: fontSize * 0.5,
            color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          text,
          style: TextStyle(fontSize: fontSize, color: textColor),
        ),
      ],
    );
  }
}
