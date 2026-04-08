import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathText extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final double lineSpacing;

  const MathText({
    super.key,
    required this.text,
    this.textStyle,
    this.lineSpacing = 6,
  });

  static final RegExp _blockRegex = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
  static final RegExp _inlineRegex = RegExp(r'\$(.+?)\$');

  @override
  Widget build(BuildContext context) {
    final resolvedStyle =
        textStyle ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final segments = _splitBlockMath(text);
    final widgets = <Widget>[];
    for (final segment in segments) {
      if (segment.isMath) {
        widgets.add(_buildBlockMath(segment.text, resolvedStyle));
      } else {
        final lines = segment.text.split('\n');
        for (var i = 0; i < lines.length; i += 1) {
          final lineWidgets = _buildInlineLine(lines[i], resolvedStyle);
          if (lineWidgets.isNotEmpty) {
            widgets.add(Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: lineWidgets,
            ));
          }
          if (i != lines.length - 1) {
            widgets.add(SizedBox(height: lineSpacing));
          }
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<_MathSegment> _splitBlockMath(String text) {
    final segments = <_MathSegment>[];
    var cursor = 0;
    for (final match in _blockRegex.allMatches(text)) {
      if (match.start > cursor) {
        segments.add(_MathSegment(
          text: text.substring(cursor, match.start),
          isMath: false,
        ));
      }
      final math = match.group(1) ?? '';
      segments.add(_MathSegment(text: math, isMath: true));
      cursor = match.end;
    }
    if (cursor < text.length) {
      segments.add(_MathSegment(
        text: text.substring(cursor),
        isMath: false,
      ));
    }
    if (segments.isEmpty) {
      segments.add(_MathSegment(text: text, isMath: false));
    }
    return segments;
  }

  Widget _buildBlockMath(String tex, TextStyle style) {
    final content = tex.trim();
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: lineSpacing / 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          content,
          mathStyle: MathStyle.display,
          textStyle: style.copyWith(color: style.color),
        ),
      ),
    );
  }

  List<Widget> _buildInlineLine(String line, TextStyle style) {
    if (line.isEmpty) return const [];
    final widgets = <Widget>[];
    var cursor = 0;
    for (final match in _inlineRegex.allMatches(line)) {
      if (match.start > cursor) {
        widgets.add(Text(
          line.substring(cursor, match.start),
          style: style,
        ));
      }
      final tex = match.group(1)?.trim() ?? '';
      if (tex.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              tex,
              mathStyle: MathStyle.text,
              textStyle: style.copyWith(color: style.color),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < line.length) {
      widgets.add(Text(line.substring(cursor), style: style));
    }
    return widgets;
  }
}

class _MathSegment {
  final String text;
  final bool isMath;

  const _MathSegment({
    required this.text,
    required this.isMath,
  });
}
