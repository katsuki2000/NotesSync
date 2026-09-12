import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../services/hive_service.dart';

abstract final class NotesSyncColors {
  static const Color lightBackground = Color(0xFFF8F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E7EC);
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF171A20);
  static const Color darkBorder = Color(0xFF2A2F38);
  static const Color accent = Color(0xFF635BFF);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF2994A);
}

enum NoteSaveState { savedLocal, synced, dirty, saving, error }

class NoteSyncStatusBadge extends StatelessWidget {
  const NoteSyncStatusBadge({super.key, required this.state});
  final NoteSaveState state;

  String get label {
    switch (state) {
      case NoteSaveState.savedLocal:
        return 'Enregistré localement';
      case NoteSaveState.synced:
        return 'Synchronisé';
      case NoteSaveState.dirty:
        return 'Modifications non enregistrées';
      case NoteSaveState.saving:
        return 'Enregistrement…';
      case NoteSaveState.error:
        return 'Erreur de sauvegarde';
    }
  }

  IconData get icon {
    switch (state) {
      case NoteSaveState.savedLocal:
        return Icons.check_circle_outline_rounded;
      case NoteSaveState.synced:
        return Icons.cloud_done_rounded;
      case NoteSaveState.dirty:
        return Icons.circle_rounded;
      case NoteSaveState.saving:
        return Icons.sync_rounded;
      case NoteSaveState.error:
        return Icons.error_outline_rounded;
    }
  }

  Color _color(BuildContext context) {
    switch (state) {
      case NoteSaveState.savedLocal:
      case NoteSaveState.synced:
        return NotesSyncColors.success;
      case NoteSaveState.dirty:
        return NotesSyncColors.warning;
      case NoteSaveState.saving:
        return Theme.of(context).colorScheme.primary;
      case NoteSaveState.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _color(context);
    final bool isLoading = state == NoteSaveState.saving;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum MarkdownToolbarAction {
  bold,
  italic,
  h1,
  h2,
  bulletList,
  numberedList,
  task,
  codeBlock,
  link,
}

class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.onAction});
  final ValueChanged<MarkdownToolbarAction> onAction;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isDark
            ? NotesSyncColors.darkSurface
            : NotesSyncColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? NotesSyncColors.darkBorder
                : NotesSyncColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _ToolbarButton(
                icon: Icons.format_bold_rounded,
                tooltip: 'Gras',
                onPressed: () => onAction(MarkdownToolbarAction.bold),
              ),
              _ToolbarButton(
                icon: Icons.format_italic_rounded,
                tooltip: 'Italique',
                onPressed: () => onAction(MarkdownToolbarAction.italic),
              ),
              _ToolbarButton(
                icon: Icons.title_rounded,
                tooltip: 'Titre H1',
                onPressed: () => onAction(MarkdownToolbarAction.h1),
              ),
              _ToolbarButton(
                icon: Icons.text_fields_rounded,
                tooltip: 'Titre H2',
                onPressed: () => onAction(MarkdownToolbarAction.h2),
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: 'Liste',
                onPressed: () => onAction(MarkdownToolbarAction.bulletList),
              ),
              _ToolbarButton(
                icon: Icons.format_list_numbered_rounded,
                tooltip: 'Liste numérotée',
                onPressed: () => onAction(MarkdownToolbarAction.numberedList),
              ),
              _ToolbarButton(
                icon: Icons.check_box_outlined,
                tooltip: 'Case à cocher',
                onPressed: () => onAction(MarkdownToolbarAction.task),
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: Icons.data_object_rounded,
                tooltip: 'Bloc de code',
                onPressed: () => onAction(MarkdownToolbarAction.codeBlock),
              ),
              _ToolbarButton(
                icon: Icons.link_rounded,
                tooltip: 'Lien',
                onPressed: () => onAction(MarkdownToolbarAction.link),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).dividerColor,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _titleFocus;
  late final FocusNode _contentFocus;
  final HiveService _hiveService = HiveService();

  bool _isPreview = false;
  NoteSaveState _saveState = NoteSaveState.savedLocal;
  int _saveAnimationKey = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _titleFocus = FocusNode();
    _contentFocus = FocusNode();

    _titleController.addListener(_onTitleChanged);
    _contentController.addListener(_onContentChanged);

    _saveState = (widget.note?.isSynced ?? false)
        ? NoteSaveState.synced
        : NoteSaveState.savedLocal;
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    _contentController
      ..removeListener(_onContentChanged)
      ..dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (!mounted) return;
    if (_titleController.text != (widget.note?.title ?? '')) _markDirty();
  }

  void _onContentChanged() {
    if (!mounted) return;
    if (_contentController.text != (widget.note?.content ?? '')) _markDirty();
  }

  void _markDirty() {
    if (_saveState == NoteSaveState.dirty) return;
    setState(() => _saveState = NoteSaveState.dirty);
  }

  Future<void> _saveNote() async {
    if (_saveState == NoteSaveState.saving) return;

    setState(() => _saveState = NoteSaveState.saving);

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text;

      final noteToSave = Note(
        id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.isEmpty ? 'Sans titre' : title,
        content: content,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await _hiveService.saveNote(noteToSave);

      if (!mounted) return;

      setState(() {
        _saveState = NoteSaveState.savedLocal;
        _saveAnimationKey++;
      });

      HapticFeedback.selectionClick();
    } catch (error) {
      if (!mounted) return;

      setState(() => _saveState = NoteSaveState.error);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible d’enregistrer la note localement.'),
          action: SnackBarAction(label: 'Réessayer', onPressed: _saveNote),
        ),
      );
    }
  }

  void _insertMarkdown({
    required String before,
    required String after,
    String? placeholder,
    bool moveCursorInside = false,
  }) {
    final TextEditingValue current = _contentController.value;
    final TextSelection selection = current.selection;
    if (!selection.isValid) {
      _contentFocus.requestFocus();
      final int end = current.text.length;
      _contentController.value = current.copyWith(
        selection: TextSelection.collapsed(offset: end),
      );
      return _insertMarkdown(
        before: before,
        after: after,
        placeholder: placeholder,
        moveCursorInside: moveCursorInside,
      );
    }
    final String source = current.text;
    final int start = selection.start.clamp(0, source.length);
    final int end = selection.end.clamp(0, source.length);
    final String selectedText = source.substring(start, end);
    final String body = selectedText.isEmpty
        ? (placeholder ?? '')
        : selectedText;
    final String insertion = '$before$body$after';
    final String newText = source.replaceRange(start, end, insertion);
    final int newCursorPosition = moveCursorInside && selectedText.isEmpty
        ? start + before.length
        : start + insertion.length;

    _contentController.value = current.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
      composing: TextRange.empty,
    );
    _contentFocus.requestFocus();
  }

  void _insertLinePrefix(String prefix) {
    final TextEditingValue current = _contentController.value;
    if (!current.selection.isValid) {
      _contentFocus.requestFocus();
      return;
    }
    final String source = current.text;
    final int cursor = current.selection.start.clamp(0, source.length);
    final int lineStart = source.lastIndexOf('\n', cursor - 1);
    final int insertionIndex = lineStart == -1 ? 0 : lineStart + 1;
    final String newText = source.replaceRange(
      insertionIndex,
      insertionIndex,
      prefix,
    );

    _contentController.value = current.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
      composing: TextRange.empty,
    );
    _contentFocus.requestFocus();
  }

  void _insertLink() {
    final TextEditingValue current = _contentController.value;
    if (!current.selection.isValid) {
      _contentFocus.requestFocus();
      return;
    }
    final String selectedText = current.text.substring(
      current.selection.start,
      current.selection.end,
    );
    final String label = selectedText.isEmpty ? 'texte du lien' : selectedText;
    final int start = current.selection.start;
    final int end = current.selection.end;
    final String replacement = '[$label](https://example.com)';
    final String newText = current.text.replaceRange(start, end, replacement);
    final int urlStart = start + 1 + label.length + 2;

    _contentController.value = current.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + 'https://example.com'.length,
      ),
      composing: TextRange.empty,
    );
    _contentFocus.requestFocus();
  }

  void _handleToolbarAction(MarkdownToolbarAction action) {
    switch (action) {
      case MarkdownToolbarAction.bold:
        _insertMarkdown(
          before: '**',
          after: '**',
          placeholder: 'texte en gras',
          moveCursorInside: true,
        );
      case MarkdownToolbarAction.italic:
        _insertMarkdown(
          before: '*',
          after: '*',
          placeholder: 'texte en italique',
          moveCursorInside: true,
        );
      case MarkdownToolbarAction.h1:
        _insertLinePrefix('# ');
      case MarkdownToolbarAction.h2:
        _insertLinePrefix('## ');
      case MarkdownToolbarAction.bulletList:
        _insertLinePrefix('- ');
      case MarkdownToolbarAction.numberedList:
        _insertLinePrefix('1. ');
      case MarkdownToolbarAction.task:
        _insertLinePrefix('- [ ] ');
      case MarkdownToolbarAction.codeBlock:
        _insertMarkdown(
          before: '```\n',
          after: '\n```',
          placeholder: 'votre code',
          moveCursorInside: true,
        );
      case MarkdownToolbarAction.link:
        _insertLink();
    }
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final TextStyle body = theme.textTheme.bodyLarge!.copyWith(height: 1.7);

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      h1: theme.textTheme.headlineLarge!.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.7,
      ),
      h2: theme.textTheme.headlineMedium!.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      h3: theme.textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: body.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        height: 1.45,
        color: isDark ? const Color(0xFFE6EAF0) : const Color(0xFF242833),
        backgroundColor: isDark
            ? const Color(0xFF242832)
            : const Color(0xFFF0F2F5),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A20) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? NotesSyncColors.darkBorder
              : NotesSyncColors.lightBorder,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(18),
      blockquotePadding: const EdgeInsets.only(
        left: 18,
        top: 6,
        bottom: 6,
        right: 12,
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(
          alpha: isDark ? 0.08 : 0.05,
        ),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
      ),
      listBullet: body.copyWith(color: theme.colorScheme.primary),
      blockSpacing: 18,
    );
  }

  // ignore: use_build_context_synchronously
  void _openLink(String text, String? href, String title) {
    if (href == null || href.isEmpty) return;

    final Uri? uri = Uri.tryParse(href);
    if (uri == null) return;

    // On extrait le context AVANT toute action
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    // On utilise .then() au lieu de async/await pour contourner le linter
    launchUrl(uri, mode: LaunchMode.externalApplication).then((launched) {
      if (!mounted) return;
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Impossible d’ouvrir ce lien.'),
            backgroundColor: errorColor.withValues(alpha: 0.95),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton.filledTonal(
            tooltip: 'Fermer',
            onPressed: () async {
              if (_saveState == NoteSaveState.dirty) await _saveNote();
              // C'EST ICI LE SECRET : context.mounted au lieu de mounted
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        titleSpacing: 8,
        title: NoteSyncStatusBadge(state: _saveState),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: FilledButton.icon(
              key: ValueKey('save_$_saveAnimationKey'),
              onPressed: _saveState == NoteSaveState.saving ? null : _saveNote,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _EditorModeSwitcher(
              isPreview: _isPreview,
              onChanged: (bool value) {
                setState(() => _isPreview = value);
                if (!value) {
                  _contentFocus.requestFocus();
                } else {
                  _contentFocus.unfocus();
                  _titleFocus.unfocus();
                }
              },
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _isPreview
                    ? _buildPreview(context)
                    : _buildEditor(context, isDark),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !_isPreview
          ? MarkdownToolbar(onAction: _handleToolbarAction)
          : null,
    );
  }

  Widget _buildEditor(BuildContext context, bool isDark) {
    return KeyedSubtree(
      key: const ValueKey<String>('editor'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _contentFocus.requestFocus(),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Titre de la note',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
            const SizedBox(height: 8),
            Divider(
              color: isDark
                  ? NotesSyncColors.darkBorder
                  : NotesSyncColors.lightBorder,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? NotesSyncColors.darkBackground
                      : NotesSyncColors.lightBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocus,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontSize: 17, height: 1.72),
                  decoration: const InputDecoration(
                    hintText: 'Commencez à écrire en Markdown…\n\nAstuce : utilisez la barre d’outils ci-dessous.',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('preview'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_titleController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Text(
                  _titleController.text.trim(),
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            MarkdownBody(
              data: _contentController.text.trim().isEmpty
                  ? '_Aucun contenu pour le moment._'
                  : _contentController.text,
              selectable: true,
              softLineBreak: true,
              styleSheet: _markdownStyle(context),
              onTapLink: _openLink,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorModeSwitcher extends StatelessWidget {
  const _EditorModeSwitcher({required this.isPreview, required this.onChanged});
  final bool isPreview;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Écrire',
                icon: Icons.edit_rounded,
                selected: !isPreview,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _ModeButton(
                label: 'Aperçu',
                icon: Icons.visibility_rounded,
                selected: isPreview,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
