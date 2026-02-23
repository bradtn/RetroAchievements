import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Cache key for wrapped text results
class _WrapCacheKey {
  final String text;
  final double fontSize;
  final String fontFamily;
  final FontWeight fontWeight;
  final double maxWidth;
  final int maxLines;
  final bool preferDashBreak;
  final bool stripDashAfterBreak;

  _WrapCacheKey({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.fontWeight,
    required this.maxWidth,
    required this.maxLines,
    required this.preferDashBreak,
    required this.stripDashAfterBreak,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _WrapCacheKey &&
          text == other.text &&
          fontSize == other.fontSize &&
          fontFamily == other.fontFamily &&
          fontWeight == other.fontWeight &&
          maxWidth == other.maxWidth &&
          maxLines == other.maxLines &&
          preferDashBreak == other.preferDashBreak &&
          stripDashAfterBreak == other.stripDashAfterBreak;

  @override
  int get hashCode => Object.hash(text, fontSize, fontFamily, fontWeight, maxWidth, maxLines, preferDashBreak, stripDashAfterBreak);
}

/// Result of text measurement
class _MeasureResult {
  final bool fits;
  final double width;
  final double height;

  _MeasureResult({required this.fits, required this.width, required this.height});
}

/// A candidate split for scoring
class _SplitCandidate {
  final String line1;
  final String line2;
  final String? line3;
  final int breakIndex;
  final int? secondBreakIndex;
  final bool isStrongBreak;
  final bool isSecondStrongBreak;
  double score;

  _SplitCandidate({
    required this.line1,
    required this.line2,
    this.line3,
    required this.breakIndex,
    this.secondBreakIndex,
    this.isStrongBreak = false,
    this.isSecondStrongBreak = false,
    this.score = 0,
  });
}

/// Layout-aware text wrapper that uses TextPainter measurement
/// to insert manual line breaks for pixel-perfect control.
class SmartTextWrapper {
  // Cache for wrapped results
  static final Map<_WrapCacheKey, String> _cache = {};
  static const int _maxCacheSize = 100;

  /// Clear the cache (call when theme/font changes)
  static void clearCache() {
    _cache.clear();
  }

  /// Strong break patterns (preferred break points)
  static final List<String> _strongBreakPatterns = [
    ' – ', // en-dash with spaces
    ' - ', // hyphen with spaces
    ': ',  // colon with space
  ];

  /// Measure if text fits within maxWidth on a single line
  static _MeasureResult _measureText(String text, TextStyle style, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout(maxWidth: double.infinity);

    final fits = textPainter.width <= maxWidth;
    return _MeasureResult(
      fits: fits,
      width: textPainter.width,
      height: textPainter.height,
    );
  }

  /// Normalize whitespace: collapse multiple spaces, trim
  static String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Apply no-break patterns by replacing internal spaces with NBSP
  static String _applyNoBreakPatterns(String text, List<RegExp> patterns) {
    if (patterns.isEmpty) return text;

    var result = text;
    for (final pattern in patterns) {
      result = result.replaceAllMapped(pattern, (match) {
        return match.group(0)!.replaceAll(' ', '\u00A0');
      });
    }
    return result;
  }

  /// Find all break candidate positions in text
  static List<({int index, bool isStrong, String delimiter})> _findBreakCandidates(String text) {
    final candidates = <({int index, bool isStrong, String delimiter})>[];

    // Find strong break candidates first
    for (final pattern in _strongBreakPatterns) {
      int searchStart = 0;
      while (true) {
        final idx = text.indexOf(pattern, searchStart);
        if (idx == -1) break;

        // Break AFTER the delimiter (so line2 doesn't start with space)
        final breakIdx = idx + pattern.length;
        candidates.add((index: breakIdx, isStrong: true, delimiter: pattern));
        searchStart = idx + 1;
      }
    }

    // Find weak break candidates (spaces)
    for (int i = 0; i < text.length; i++) {
      if (text[i] == ' ' && text[i] != '\u00A0') {
        // Check if this position is already a strong break
        final isAlreadyStrong = candidates.any((c) =>
          c.index == i + 1 || (c.index > i && c.index <= i + 3));
        if (!isAlreadyStrong) {
          candidates.add((index: i + 1, isStrong: false, delimiter: ' '));
        }
      }
    }

    // Sort by index
    candidates.sort((a, b) => a.index.compareTo(b.index));

    return candidates;
  }

  /// Count words in a string
  static int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// Get the last word of a string
  static String _lastWord(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+'));
    return words.last;
  }

  /// Get the first word of a string
  static String _firstWord(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+'));
    return words.first;
  }

  /// Score a 2-line split candidate (lower is better)
  static double _scoreTwoLineSplit(
    _SplitCandidate candidate,
    double line1Width,
    double line2Width,
    double maxWidth,
  ) {
    double score = 0;

    final line1 = candidate.line1.trim();
    final line2 = candidate.line2.trim();
    final line2Words = _countWords(line2);
    final lastWordLine2 = _lastWord(line2);
    final firstWordLine2 = _firstWord(line2);
    final line2CharCount = line2.length;

    // === Hard penalties ===

    // Line2 has only 1 word (orphan line)
    if (line2Words == 1) {
      score += 1000;
    }

    // Line2 has only 2 short words (like "Cut Man", "vs. X")
    if (line2Words == 2 && line2CharCount <= 12) {
      score += 800;
    }

    // Line2 is very short overall (less than 15 chars)
    if (line2CharCount <= 15 && line2Words <= 2) {
      score += 600;
    }

    // Last token on line2 is very short (orphan word effect)
    if (lastWordLine2.length <= 3 && line2Words > 1) {
      score += 500;
    }

    // Line2 is a tiny fragment (less than 25% of max width)
    if (line2Width < maxWidth * 0.25 && line2Width > 0) {
      score += 500;
    }

    // Line2 starts with very short word and ends quickly
    if (firstWordLine2.length <= 4 && line2Words <= 2) {
      score += 400;
    }

    // Line1 ends with "vs." or "vs" - BAD break point
    if (line1.endsWith('vs.') || line1.endsWith('vs')) {
      score += 800;
    }

    // Line1 is much longer than line2 (unbalanced)
    if (line1Width > line2Width * 2.5 && line2Width > 0) {
      score += 200;
    }

    // === Balance penalty ===
    // Prefer balanced line lengths
    final balanceDiff = (line1Width - line2Width).abs();
    score += balanceDiff * 0.3; // Weighted balance penalty

    // === Bonuses (negative penalties) ===

    // Break at strong punctuation boundary
    if (candidate.isStrongBreak) {
      score -= 200;
    }

    // Line2 starts with a dash clause (looks clean)
    if (line2.startsWith('–') || line2.startsWith('-')) {
      score -= 150;
    }

    // Line2 starts with "vs." (keeps "vs. X" together)
    if (line2.toLowerCase().startsWith('vs.') || line2.toLowerCase().startsWith('vs ')) {
      score -= 100;
    }

    // Good balance (lines within 30% of each other)
    if (balanceDiff < maxWidth * 0.3) {
      score -= 50;
    }

    // Line2 has good length (3+ words or 20+ chars)
    if (line2Words >= 3 || line2CharCount >= 20) {
      score -= 100;
    }

    return score;
  }

  /// Score a 3-line split candidate
  static double _scoreThreeLineSplit(
    _SplitCandidate candidate,
    double line1Width,
    double line2Width,
    double line3Width,
    double maxWidth,
  ) {
    double score = 0;

    final line3 = candidate.line3?.trim() ?? '';
    final line3Words = _countWords(line3);
    final lastWordLine3 = _lastWord(line3);

    // === Hard penalties for final line ===

    // Final line has only 1 word
    if (line3Words == 1) {
      score += 1200; // Even higher penalty for 3-line orphan
    }

    // Final line last word is very short
    if (lastWordLine3.length <= 3 && line3Words > 1) {
      score += 600;
    }

    // Final line is tiny fragment
    if (line3Width < maxWidth * 0.15 && line3Width > 0) {
      score += 600;
    }

    // === Balance penalties ===
    final avgWidth = (line1Width + line2Width + line3Width) / 3;
    final variance = ((line1Width - avgWidth).abs() +
                      (line2Width - avgWidth).abs() +
                      (line3Width - avgWidth).abs()) / 3;
    score += variance * 0.3;

    // === Bonuses ===
    if (candidate.isStrongBreak) score -= 150;
    if (candidate.isSecondStrongBreak) score -= 150;

    return score;
  }

  /// Try breaking at dash pattern (simple rule: everything after dash on new line)
  /// Returns null if no valid break found or lines don't fit
  /// If stripDash is true, removes the leading dash from line2 for cleaner display
  static String? _tryDashBreak(String text, TextStyle style, double maxWidth, int maxLines, {bool stripDash = false}) {
    // Look for dash patterns (various dash types with/without spaces)
    // Covers: hyphen-minus (-), en-dash (–), em-dash (—), minus sign (−),
    // hyphen (‐), figure dash (‒), horizontal bar (―)
    final dashPatterns = [
      ' – ',  // en-dash with spaces
      ' — ',  // em-dash with spaces
      ' - ',  // hyphen-minus with spaces
      ' − ',  // minus sign with spaces
      ' ‐ ',  // hyphen with spaces
      ' ‒ ',  // figure dash with spaces
      ' ― ',  // horizontal bar with spaces
      '– ',   // en-dash with trailing space
      '— ',   // em-dash with trailing space
      '- ',   // hyphen-minus with trailing space
      '− ',   // minus sign with trailing space
    ];

    for (final dash in dashPatterns) {
      final idx = text.indexOf(dash);
      if (idx == -1) continue;

      // Break BEFORE dash: line1 = before, line2 = dash + after
      final line1 = text.substring(0, idx).trim();
      var line2 = text.substring(idx).trim();

      // Strip leading dash if requested (for cleaner display)
      // Matches all common dash/hyphen Unicode characters followed by optional whitespace
      if (stripDash) {
        line2 = line2.replaceFirst(RegExp(r'^[\-–—−‐‑‒―]\s*'), '');
      }

      if (line1.isEmpty || line2.isEmpty) continue;

      final m1 = _measureText(line1, style, maxWidth);
      final m2 = _measureText(line2, style, maxWidth);

      // If both lines fit, we're done
      if (m1.fits && m2.fits) {
        return '$line1\n$line2';
      }

      // If line2 doesn't fit but we have 3 lines available, try splitting line2
      if (m1.fits && !m2.fits && maxLines >= 3) {
        // Try to split line2 at a good point
        final line2Split = _findBestTwoLineSplit(line2, style, maxWidth);
        if (line2Split != null) {
          return '$line1\n$line2Split';
        }
      }

      // If line1 doesn't fit, try splitting line1 and keeping line2
      if (!m1.fits && m2.fits && maxLines >= 3) {
        final line1Split = _findBestTwoLineSplit(line1, style, maxWidth);
        if (line1Split != null) {
          return '$line1Split\n$line2';
        }
      }
    }

    return null;
  }

  /// Generate forced split candidates for semantic breaks
  static List<_SplitCandidate> _generateSemanticBreakCandidates(String text) {
    final candidates = <_SplitCandidate>[];

    // Look for dash patterns
    final dashPatterns = [' – ', ' - '];

    for (final dash in dashPatterns) {
      final idx = text.indexOf(dash);
      if (idx == -1) continue;

      // Option A: Break BEFORE dash (line2 starts with dash)
      final line1A = text.substring(0, idx).trim();
      final line2A = text.substring(idx).trim();
      if (line1A.isNotEmpty && line2A.isNotEmpty) {
        candidates.add(_SplitCandidate(
          line1: line1A,
          line2: line2A,
          breakIndex: idx,
          isStrongBreak: true,
        ));
      }

      // Option B: Break AFTER dash (dash ends line1)
      final afterDash = idx + dash.length;
      final line1B = text.substring(0, afterDash).trim();
      final line2B = text.substring(afterDash).trim();
      if (line1B.isNotEmpty && line2B.isNotEmpty) {
        candidates.add(_SplitCandidate(
          line1: line1B,
          line2: line2B,
          breakIndex: afterDash,
          isStrongBreak: true,
        ));
      }
    }

    // Look for "vs." or "vs " pattern - prefer breaking BEFORE it
    final vsPatterns = [' vs. ', ' vs '];
    for (final vs in vsPatterns) {
      final idx = text.toLowerCase().indexOf(vs.toLowerCase());
      if (idx == -1) continue;

      // Break BEFORE "vs." so line2 = "vs. Something"
      final line1 = text.substring(0, idx).trim();
      final line2 = text.substring(idx).trim();
      if (line1.isNotEmpty && line2.isNotEmpty) {
        candidates.add(_SplitCandidate(
          line1: line1,
          line2: line2,
          breakIndex: idx,
          isStrongBreak: true,
        ));
      }
    }

    return candidates;
  }

  /// Find best 2-line split
  static String? _findBestTwoLineSplit(
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    final candidates = <_SplitCandidate>[];
    final breakPoints = _findBreakCandidates(text);

    // Add semantic break candidates (dashes, vs., etc.)
    candidates.addAll(_generateSemanticBreakCandidates(text));

    // Generate candidates from all break points
    for (final bp in breakPoints) {
      if (bp.index <= 0 || bp.index >= text.length) continue;

      final line1 = text.substring(0, bp.index).trim();
      final line2 = text.substring(bp.index).trim();

      if (line1.isEmpty || line2.isEmpty) continue;

      candidates.add(_SplitCandidate(
        line1: line1,
        line2: line2,
        breakIndex: bp.index,
        isStrongBreak: bp.isStrong,
      ));
    }

    if (candidates.isEmpty) return null;

    // Measure and score each candidate
    _SplitCandidate? bestCandidate;
    double bestScore = double.infinity;

    for (final candidate in candidates) {
      final m1 = _measureText(candidate.line1, style, maxWidth);
      final m2 = _measureText(candidate.line2, style, maxWidth);

      // Both lines must fit
      if (!m1.fits || !m2.fits) continue;

      candidate.score = _scoreTwoLineSplit(
        candidate,
        m1.width,
        m2.width,
        maxWidth,
      );

      if (candidate.score < bestScore) {
        bestScore = candidate.score;
        bestCandidate = candidate;
      }
    }

    if (bestCandidate == null) return null;

    return '${bestCandidate.line1}\n${bestCandidate.line2}';
  }

  /// Find best 3-line split
  static String? _findBestThreeLineSplit(
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    final breakPoints = _findBreakCandidates(text);
    if (breakPoints.length < 2) return null;

    final candidates = <_SplitCandidate>[];

    // Try combinations of break points (limited to avoid O(n^2) explosion)
    final maxTries = breakPoints.length.clamp(0, 15);

    for (int i = 0; i < maxTries; i++) {
      for (int j = i + 1; j < maxTries; j++) {
        final bp1 = breakPoints[i];
        final bp2 = breakPoints[j];

        if (bp1.index <= 0 || bp2.index >= text.length) continue;
        if (bp2.index <= bp1.index) continue;

        final line1 = text.substring(0, bp1.index).trim();
        final line2 = text.substring(bp1.index, bp2.index).trim();
        final line3 = text.substring(bp2.index).trim();

        if (line1.isEmpty || line2.isEmpty || line3.isEmpty) continue;

        candidates.add(_SplitCandidate(
          line1: line1,
          line2: line2,
          line3: line3,
          breakIndex: bp1.index,
          secondBreakIndex: bp2.index,
          isStrongBreak: bp1.isStrong,
          isSecondStrongBreak: bp2.isStrong,
        ));
      }
    }

    if (candidates.isEmpty) return null;

    // Measure and score
    _SplitCandidate? bestCandidate;
    double bestScore = double.infinity;

    for (final candidate in candidates) {
      final m1 = _measureText(candidate.line1, style, maxWidth);
      final m2 = _measureText(candidate.line2, style, maxWidth);
      final m3 = _measureText(candidate.line3!, style, maxWidth);

      if (!m1.fits || !m2.fits || !m3.fits) continue;

      candidate.score = _scoreThreeLineSplit(
        candidate,
        m1.width,
        m2.width,
        m3.width,
        maxWidth,
      );

      if (candidate.score < bestScore) {
        bestScore = candidate.score;
        bestCandidate = candidate;
      }
    }

    if (bestCandidate == null) return null;

    return '${bestCandidate.line1}\n${bestCandidate.line2}\n${bestCandidate.line3}';
  }

  /// Main entry point: smart wrap with measurement
  ///
  /// Parameters:
  /// - [text]: The text to wrap
  /// - [style]: TextStyle used for measurement (must match render style)
  /// - [maxWidth]: Available width after padding/margins
  /// - [maxLines]: Maximum lines (default 2 for titles)
  /// - [noBreakPatterns]: Optional RegExp patterns for phrases that shouldn't break
  /// - [preferDashBreak]: If true, always breaks before dash patterns (good for descriptions)
  /// - [stripDashAfterBreak]: If true, removes the dash from display after breaking (cleaner look)
  ///
  /// Returns the text with '\n' inserted at optimal break points.
  static String smartWrapMeasured({
    required String text,
    required TextStyle style,
    required double maxWidth,
    int maxLines = 2,
    List<RegExp> noBreakPatterns = const [],
    bool preferDashBreak = false,
    bool stripDashAfterBreak = false,
  }) {
    // Check cache first
    final cacheKey = _WrapCacheKey(
      text: text,
      fontSize: style.fontSize ?? 14,
      fontFamily: style.fontFamily ?? '',
      fontWeight: style.fontWeight ?? FontWeight.normal,
      maxWidth: maxWidth,
      maxLines: maxLines,
      preferDashBreak: preferDashBreak,
      stripDashAfterBreak: stripDashAfterBreak,
    );

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Normalize and preprocess
    var processed = _normalizeWhitespace(text);
    if (processed.isEmpty) return '';

    // Apply no-break patterns
    processed = _applyNoBreakPatterns(processed, noBreakPatterns);

    // If preferDashBreak is true, try breaking at dash FIRST (even if text fits on one line)
    // This ensures consistent dash-based line breaking for descriptions
    if (preferDashBreak) {
      final dashResult = _tryDashBreak(processed, style, maxWidth, maxLines, stripDash: stripDashAfterBreak);
      if (dashResult != null) {
        _addToCache(cacheKey, dashResult);
        return dashResult;
      }
    }

    // Check if text fits on single line
    final singleLineMeasure = _measureText(processed, style, maxWidth);
    if (singleLineMeasure.fits) {
      _addToCache(cacheKey, processed);
      return processed;
    }

    // Try to find best split
    String? result;

    if (maxLines == 2) {
      result = _findBestTwoLineSplit(processed, style, maxWidth);
    } else if (maxLines >= 3) {
      // Try 2 lines first
      result = _findBestTwoLineSplit(processed, style, maxWidth);

      // Check if we need 3 lines
      bool needsThreeLines = false;

      if (result == null) {
        // 2-line split failed completely
        needsThreeLines = true;
      } else {
        // Check if the 2-line result has issues
        final lines = result.split('\n');
        if (lines.length == 2) {
          final line2Words = _countWords(lines[1]);
          final line2Chars = lines[1].trim().length;

          // Orphan detection: very short line2
          if (line2Words <= 2 && line2Chars <= 15) {
            needsThreeLines = true;
          }
          // Single word orphan
          if (line2Words == 1) {
            needsThreeLines = true;
          }
        }
      }

      if (needsThreeLines) {
        final threeLineResult = _findBestThreeLineSplit(processed, style, maxWidth);
        if (threeLineResult != null) {
          final threeLines = threeLineResult.split('\n');
          // Verify 3-line result is actually better
          if (threeLines.length == 3) {
            final lastLineWords = _countWords(threeLines[2]);
            final lastLineChars = threeLines[2].trim().length;
            // Accept 3-line if last line isn't a single short word
            if (lastLineWords > 1 || lastLineChars > 8) {
              result = threeLineResult;
            }
          }
        }
      }
    }

    // Fallback to original if no good split found
    final finalResult = result ?? processed;
    _addToCache(cacheKey, finalResult);
    return finalResult;
  }

  /// Add to cache with size limit
  static void _addToCache(_WrapCacheKey key, String value) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entries (first 20%)
      final keysToRemove = _cache.keys.take(_maxCacheSize ~/ 5).toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = value;
  }
}

/// Convenience extension for easier usage
extension SmartWrapExtension on String {
  /// Wrap text with smart line breaking
  String smartWrap({
    required TextStyle style,
    required double maxWidth,
    int maxLines = 2,
    List<RegExp> noBreakPatterns = const [],
  }) {
    return SmartTextWrapper.smartWrapMeasured(
      text: this,
      style: style,
      maxWidth: maxWidth,
      maxLines: maxLines,
      noBreakPatterns: noBreakPatterns,
    );
  }
}
