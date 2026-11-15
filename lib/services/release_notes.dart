/// Release notes parsed into renderable pieces.
///
/// GitHub release bodies are Markdown. The update sheet used to render the raw
/// body as one text blob, which read as an unformatted wall of `- item` lines.
/// This parser turns the body (or a list of conventional-commit subjects) into
/// headings / bullets / paragraphs the sheet can style.
enum ReleaseNoteKind { heading, bullet, text }

class ReleaseNoteBlock {
  const ReleaseNoteBlock(this.kind, this.text);

  final ReleaseNoteKind kind;
  final String text;
}

/// Ordered, renderable release notes.
class ReleaseNotes {
  const ReleaseNotes(this.blocks);

  final List<ReleaseNoteBlock> blocks;

  static const ReleaseNotes empty = ReleaseNotes(<ReleaseNoteBlock>[]);

  bool get isEmpty => blocks.isEmpty;

  /// How many individual changes were listed, shown as "更新内容 · 7 项".
  int get changeCount =>
      blocks.where((block) => block.kind == ReleaseNoteKind.bullet).length;

  // ---------------------------------------------------------------------------
  // Markdown body
  // ---------------------------------------------------------------------------

  static final RegExp _headingRe = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bulletRe = RegExp(r'^[-*+]\s+(.*)$');
  static final RegExp _orderedRe = RegExp(r'^\d+[.)]\s+(.*)$');
  static final RegExp _dividerRe = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$');
  static final RegExp _skipRe = RegExp(r'^(?:\*\*)?full changelog', caseSensitive: false);

  /// Headings GitHub's own generator emits that read better in Chinese.
  static const Map<String, String> _headingAliases = {
    "what's changed": '变更内容',
  };

  /// Parse a GitHub release body into blocks.
  factory ReleaseNotes.parse(String raw) {
    final blocks = <ReleaseNoteBlock>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = _cleanInline(paragraph.join(' '));
      if (text.isNotEmpty) {
        blocks.add(ReleaseNoteBlock(ReleaseNoteKind.text, text));
      }
      paragraph.clear();
    }

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      if (trimmed.startsWith('<!--')) continue;
      if (_dividerRe.hasMatch(trimmed)) {
        flushParagraph();
        continue;
      }
      final heading = _headingRe.firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        final text = _cleanHeading(_cleanInline(heading.group(2) ?? ''));
        if (text.isNotEmpty) {
          blocks.add(ReleaseNoteBlock(ReleaseNoteKind.heading, text));
        }
        continue;
      }
      final bullet =
          _bulletRe.firstMatch(trimmed) ?? _orderedRe.firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        final text = _cleanInline(bullet.group(1) ?? '');
        if (text.isNotEmpty) {
          blocks.add(ReleaseNoteBlock(ReleaseNoteKind.bullet, text));
        }
        continue;
      }
      if (_skipRe.hasMatch(trimmed)) continue;
      paragraph.add(trimmed);
    }
    flushParagraph();
    return ReleaseNotes(blocks);
  }

  // ---------------------------------------------------------------------------
  // Conventional commits (used when a release ships without a body)
  // ---------------------------------------------------------------------------

  /// Commit types in display order, mirroring `scripts/generate_release_notes.py`.
  static const List<(String, String)> _commitGroups = [
    ('feat', '新功能'),
    ('fix', '问题修复'),
    ('perf', '性能优化'),
    ('style', '界面与体验'),
    ('refactor', '重构'),
    ('docs', '文档'),
  ];

  static final RegExp _commitRe = RegExp(r'^(\w+)(?:\(([^)]*)\))?!?:\s*(.+)$');

  /// Group commit subjects into the same sections the release workflow emits.
  factory ReleaseNotes.fromCommits(Iterable<String> subjects) {
    final grouped = <String, List<String>>{};
    final other = <String>[];

    for (final raw in subjects) {
      final subject = raw.trim();
      if (subject.isEmpty || subject.startsWith('Merge ')) continue;
      final match = _commitRe.firstMatch(subject);
      if (match == null) {
        other.add(subject);
        continue;
      }
      final type = match.group(1)!.toLowerCase();
      final description = match.group(3)!.trim();
      String? label;
      for (final group in _commitGroups) {
        if (group.$1 == type) label = group.$2;
      }
      if (label == null) {
        other.add(description);
        continue;
      }
      (grouped[label] ??= <String>[]).add(description);
    }

    final blocks = <ReleaseNoteBlock>[];
    for (final group in _commitGroups) {
      final items = grouped[group.$2];
      if (items == null || items.isEmpty) continue;
      blocks.add(ReleaseNoteBlock(ReleaseNoteKind.heading, group.$2));
      for (final item in items) {
        blocks.add(ReleaseNoteBlock(ReleaseNoteKind.bullet, item));
      }
    }
    if (other.isNotEmpty) {
      blocks.add(const ReleaseNoteBlock(ReleaseNoteKind.heading, '其它改动'));
      for (final item in other) {
        blocks.add(ReleaseNoteBlock(ReleaseNoteKind.bullet, item));
      }
    }
    return ReleaseNotes(blocks);
  }

  // ---------------------------------------------------------------------------
  // Inline Markdown cleanup
  // ---------------------------------------------------------------------------

  static final RegExp _commentRe = RegExp(r'<!--.*?-->');
  static final RegExp _linkRe = RegExp(r'\[([^\]]*)\]\(([^)]*)\)');
  static final RegExp _htmlRe = RegExp(r'<[^>]*>');
  static final RegExp _emphasisRe = RegExp(r'\*\*|__|`|\*');
  static final RegExp _leadingMarkersRe = RegExp(r'^(?:[-*+]\s*)+');
  static final RegExp _spacesRe = RegExp(r'\s+');

  /// Markdown/HTML removal leaves stray spaces inside Chinese sentences
  /// ("收藏按钮改用 心形图标"), so collapse whitespace between CJK characters.
  static final RegExp _cjkSpaceRe = RegExp(
      r'(?<=[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef])[ \t]+'
      r'(?=[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef])');

  static String _cleanInline(String text) {
    var value = text.replaceAll(_commentRe, '');
    value = value.replaceAllMapped(_linkRe, (match) => match.group(1) ?? '');
    value = value.replaceAll(_htmlRe, '');
    value = value.replaceAll(_emphasisRe, '');
    value = value.replaceAll(_spacesRe, ' ');
    value = value.replaceAll(_cjkSpaceRe, '');
    value = value.trim();
    return value.replaceFirst(_leadingMarkersRe, '').trim();
  }

  static String _cleanHeading(String text) {
    final cleaned = text.replaceFirst(RegExp(r'\s*#*$'), '').trim();
    return _headingAliases[cleaned.toLowerCase()] ?? cleaned;
  }
}
