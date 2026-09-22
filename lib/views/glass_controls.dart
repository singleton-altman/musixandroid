import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/player_glass.dart';

/// Shared glass controls provide their own material, without an outer glass card.
class GlassFilterBar extends StatelessWidget {
  final List<(String, String)> items;
  final String selected;
  final ValueChanged<String> onChanged;

  const GlassFilterBar(
      {super.key,
      required this.items,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final index = items.indexWhere((item) => item.$1 == selected);
    return GlassSegmentedControl.scrollable(
      segments: [for (final item in items) GlassSegment(label: item.$2)],
      selectedIndex: index < 0 ? 0 : index,
      onSegmentSelected: (i) => onChanged(items[i].$1),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      height: 44,
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      settings: playerGlassSettings(context),
      selectedTextStyle: TextStyle(
          color: scheme.primary, fontSize: 14, fontWeight: FontWeight.w600),
      unselectedTextStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
    );
  }
}

class MusicSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const MusicSearchField(
      {super.key,
      required this.controller,
      required this.onChanged,
      required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSearchBar(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      placeholder: '歌曲、艺人、专辑、歌单或分享链接',
      clearButtonSemanticLabel: '清除搜索',
      height: 52,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      settings: playerGlassSettings(context),
      searchIconColor: scheme.primary,
      clearIconColor: scheme.onSurfaceVariant,
      textStyle: TextStyle(color: scheme.onSurface, fontSize: 16),
      placeholderStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
    );
  }
}

/// Glass bottom sheet that can also return a value, so sheets that pick
/// something (a replacement source, a subscription option) stay glass while
/// keeping the `Navigator.pop(value)` contract.
Future<T?> showMusicGlassSheet<T>(BuildContext context, Widget child,
    {double halfSize = 0.62, double fullSize = 0.92}) async {
  final settings = playerGlassSettings(context).copyWith(blur: 18);
  return GlassModalSheet.show<T>(
    context: context,
    useRootNavigator: true,
    halfSize: halfSize,
    fullSize: fullSize,
    fillThreshold: 1,
    settings: settings,
    halfSettings: settings,
    fullSettings: settings,
    expandedColor: Colors.transparent,
    expandedDarkColor: Colors.transparent,
    quality: GlassQuality.standard,
    topBorderRadius: 28,
    fullTopBorderRadius: 28,
    bottomBorderRadius: 28,
    horizontalMargin: 8,
    bottomMargin: 8,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    enableInteractionGlow: false,
    enableSaturationGlow: false,
    builder: (_) => Material(
      type: MaterialType.transparency,
      child: SafeArea(top: false, child: child),
    ),
  );
}

/// Glass action list for long-press surfaces, where there is no trigger widget
/// to anchor a menu to. Rows match the anchored menu items, so both entry
/// points read as the same control.
Future<void> showMusicGlassActionSheet(
  BuildContext context,
  List<MusicMenuAction> actions, {
  String? title,
  double halfSize = 0.5,
  double fullSize = 0.86,
}) async {
  final scheme = Theme.of(context).colorScheme;
  MusicMenuAction? picked;
  await showMusicGlassSheet<void>(
    context,
    Builder(builder: (sheetContext) {
      final headerCount = actions.where((a) => a.isHeader).length;
      final rowCount = actions.length - headerCount;
      final height = (headerCount * 30.0 + rowCount * 52.0 + 16)
          .clamp(120.0, MediaQuery.sizeOf(sheetContext).height * 0.8);
      return SizedBox(
        height: height,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 10),
              children: [
                for (final action in actions)
                  if (action.isHeader)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                      child: Text(action.title,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    GlassMenuItem(
                      height: 52,
                      maxLines: 2,
                      title: action.title,
                      icon: action.icon == null ? null : Icon(action.icon),
                      isDestructive: action.destructive,
                      isSelected: action.selected,
                      enabled: action.enabled,
                      titleStyle: TextStyle(
                          color: action.destructive
                              ? scheme.error
                              : scheme.onSurface,
                          fontSize: 15),
                      iconColor:
                          action.destructive ? scheme.error : scheme.onSurface,
                      onTap: () {
                        picked = action;
                        Navigator.of(sheetContext).pop();
                      },
                    ),
              ],
            ),
          ),
        ]),
      );
    }),
    halfSize: halfSize,
    fullSize: fullSize,
  );
  picked?.onTap?.call();
}

class MusicMenuAction {
  final String title;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;
  /// Renders a check mark and highlights the row — used by filter menus.
  final bool selected;

  /// Tappable unless false (section headers, in-flight rows).
  final bool enabled;

  /// A dim, non-tappable section label instead of an action row.
  final bool isHeader;

  const MusicMenuAction(this.title, this.icon, this.onTap,
      {this.destructive = false,
      this.selected = false,
      this.enabled = true})
      : isHeader = false;

  /// Section label inside a menu, e.g. "级别" above a group of filter rows.
  const MusicMenuAction.header(this.title)
      : icon = null,
        onTap = null,
        destructive = false,
        selected = false,
        enabled = false,
        isHeader = true;
}

/// Anchored menu with system-back dismissal, including inside nested Navigators.
class MusicActionsMenu extends StatefulWidget {
  final List<MusicMenuAction> actions;
  final String? title;
  final Color? triggerColor;

  /// Render the trigger as a circular glass button instead of a bare icon —
  /// used on chrome-less surfaces like the Now Playing page.
  final bool glassTrigger;

  /// Trigger glyph when [glassTrigger] is set (filters use their own icon).
  final IconData triggerIcon;

  /// Screen-reader label for the trigger, e.g. "歌曲操作" / "筛选".
  final String triggerLabel;

  /// Fully custom trigger, tapped to open the menu. Overrides [glassTrigger],
  /// [triggerIcon] and [triggerLabel] — used by in-row selectors that show the
  /// current value plus a chevron.
  final Widget? trigger;
  const MusicActionsMenu(
      {super.key,
      required this.actions,
      this.title,
      this.triggerColor,
      this.glassTrigger = false,
      this.triggerIcon = Icons.more_horiz,
      this.triggerLabel = '歌曲操作',
      this.trigger});

  @override
  State<MusicActionsMenu> createState() => _MusicActionsMenuState();
}

class _MusicActionsMenuState extends State<MusicActionsMenu> {
  final _controller = GlassMenuController();
  LocalHistoryEntry? _history;
  bool _disposing = false;

  void _onClose() {
    final history = _history;
    _history = null;
    history?.remove();
  }

  void _toggle() {
    if (_controller.isOpen) {
      _controller.close();
      return;
    }
    _history = LocalHistoryEntry(onRemove: () {
      _history = null;
      if (!_disposing) _controller.close();
    });
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    _controller.open();
  }

  @override
  void dispose() {
    _disposing = true;
    _onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1).clamp(1.0, 2.0);
    final itemHeight = 52.0 * textScale;
    final headerHeight = 30.0 * textScale;
    final headerCount = widget.actions.where((a) => a.isHeader).length;
    final rowCount = widget.actions.length - headerCount;
    final availableHeight = (media.size.height -
            media.padding.vertical -
            media.viewInsets.bottom -
            32)
        .clamp(120.0, double.infinity);
    return GlassMenu(
      controller: _controller,
      onClose: _onClose,
      autoAdjustToScreen: true,
      menuPadding: const EdgeInsets.all(12),
      menuWidth: (media.size.width - 32).clamp(200.0, 320.0),
      menuBorderRadius: 22,
      itemBorderRadius: 12,
      menuHeight: (rowCount * itemHeight +
              headerCount * headerHeight +
              (widget.title == null ? 20 : 76 * textScale))
          .clamp(0.0, availableHeight),
      quality: GlassQuality.standard,
      settings: playerGlassSettings(context).copyWith(blur: 18),
      triggerBuilder: (_, __) => widget.trigger != null
          ? Semantics(
              button: true,
              label: widget.triggerLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: widget.trigger,
              ),
            )
          : widget.glassTrigger
          ? GlassIconButton(
              icon: Icon(widget.triggerIcon,
                  color: widget.triggerColor ?? scheme.onSurfaceVariant),
              onPressed: _toggle,
              size: 44,
              iconSize: 20,
              semanticLabel: widget.triggerLabel,
              useOwnLayer: true,
              quality: GlassQuality.standard,
              settings: playerGlassSettings(context).copyWith(blur: 12),
            )
          : IconButton(
              tooltip: widget.triggerLabel,
              onPressed: _toggle,
              icon: Icon(widget.triggerIcon,
                  color: widget.triggerColor ?? scheme.onSurfaceVariant),
            ),
      items: [
        if (widget.title != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Text(widget.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      decoration: TextDecoration.none))),
        for (final action in widget.actions)
          if (action.isHeader)
            // Dim section label, matching the old popup's grouped headers.
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                child: Text(action.title,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none)))
          else
            GlassMenuItem(
              height: itemHeight,
              maxLines: 2,
              title: action.title,
              icon: action.icon == null ? null : Icon(action.icon),
              isDestructive: action.destructive,
              isSelected: action.selected,
              enabled: action.enabled,
              trailing: action.selected
                  ? Icon(Icons.check, size: 18, color: scheme.primary)
                  : null,
              titleStyle: TextStyle(
                  color: action.destructive ? scheme.error : scheme.onSurface,
                  fontSize: 15),
              iconColor:
                  action.destructive ? scheme.error : scheme.onSurface,
              onTap: action.onTap ?? () {},
            ),
      ],
    );
  }
}

/// In-row selector: shows the current option with a chevron and opens a glass
/// menu of the alternatives. Drop-in replacement for Material's
/// `DropdownButton` so settings rows keep one visual language.
class MusicSelectButton<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Heading shown at the top of the menu, usually the row's label.
  final String? menuTitle;
  final String? semanticLabel;
  final Color? color;
  const MusicSelectButton({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.menuTitle,
    this.semanticLabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = options.where((o) => o.$1 == value).map((o) => o.$2);
    final text = current.isEmpty ? '' : current.first;
    final ink = color ?? scheme.onSurface;
    return MusicActionsMenu(
      title: menuTitle,
      triggerLabel: semanticLabel ?? menuTitle ?? text,
      trigger: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: TextStyle(color: ink, fontSize: 14)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 18, color: ink.withValues(alpha: 0.7)),
        ]),
      ),
      actions: [
        for (final o in options)
          MusicMenuAction(o.$2, null, () => onChanged(o.$1),
              selected: o.$1 == value),
      ],
    );
  }
}
