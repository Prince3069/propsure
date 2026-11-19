import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';

// Propsure component library.
//
// Every screen is composed from these semantic components so buttons, inputs,
// pills, rows and headers look and behave the same everywhere. All tappable
// controls are at least 48 logical pixels tall, expose semantics, and respect
// the system text scale (nothing here hard-codes a fixed text height).

enum PsTone { success, neutral, warning, danger, info }

Color _toneBg(PsTone t) {
  switch (t) {
    case PsTone.success:
      return AppColors.primaryPale2;
    case PsTone.neutral:
      return AppColors.muted;
    case PsTone.warning:
      return AppColors.warningPale;
    case PsTone.danger:
      return AppColors.errorPale;
    case PsTone.info:
      return const Color(0xFFE5EEF7);
  }
}

Color _toneFg(PsTone t) {
  switch (t) {
    case PsTone.success:
      return AppColors.primary;
    case PsTone.neutral:
      return AppColors.text2;
    case PsTone.warning:
      return AppColors.goldDark;
    case PsTone.danger:
      return AppColors.error;
    case PsTone.info:
      return AppColors.info;
  }
}

// ─── HEADLINES ───────────────────────────────────────────────────────────────

/// Two-tone display headline: charcoal first part, green accent.
class PsHeadline extends StatelessWidget {
  final String dark;
  final String? accent;
  final bool stacked; // accent on its own line
  final double? size;

  const PsHeadline(this.dark, {super.key, this.accent, this.stacked = true, this.size});

  @override
  Widget build(BuildContext context) {
    final base = AppText.display.copyWith(fontSize: size);
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: dark, style: base),
          if (accent != null) ...[
            TextSpan(text: stacked ? '\n' : ' '),
            TextSpan(text: accent, style: base.copyWith(color: AppColors.primary)),
          ],
        ]),
      ),
    );
  }
}

// ─── BUTTONS ─────────────────────────────────────────────────────────────────

enum PsButtonKind { primary, outline, ghost, onDark, danger }

class PsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PsButtonKind kind;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;

  const PsButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = PsButtonKind.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    Color bg;
    Color fg;
    BorderSide? side;
    switch (kind) {
      case PsButtonKind.primary:
        bg = enabled ? AppColors.primary : AppColors.muted;
        fg = enabled ? Colors.white : AppColors.text3;
        break;
      case PsButtonKind.outline:
        bg = AppColors.card;
        fg = enabled ? AppColors.primary : AppColors.text3;
        side = BorderSide(color: enabled ? AppColors.primary : AppColors.border2, width: 1.4);
        break;
      case PsButtonKind.ghost:
        bg = Colors.transparent;
        fg = enabled ? AppColors.primary : AppColors.text3;
        break;
      case PsButtonKind.onDark:
        bg = Colors.white;
        fg = AppColors.primary;
        break;
      case PsButtonKind.danger:
        bg = AppColors.card;
        fg = AppColors.error;
        side = const BorderSide(color: AppColors.error, width: 1.4);
        break;
    }
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else ...[
          if (icon != null) ...[Icon(icon, size: 22, color: fg), const SizedBox(width: 10)],
          Flexible(
            child: Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppText.button.copyWith(color: fg)),
          ),
          if (trailingIcon != null) ...[const SizedBox(width: 10), Icon(trailingIcon, size: 22, color: fg)],
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: side ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Underlined green text link with an optional chevron, e.g. "Watch walkthroughs ›".
class PsLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool chevron;
  final bool underline;
  const PsLink(this.label, {super.key, this.onTap, this.chevron = false, this.underline = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(label,
                  style: AppText.label.copyWith(
                    color: AppColors.primary,
                    decoration: underline ? TextDecoration.underline : null,
                    decorationColor: AppColors.primary,
                  )),
            ),
            if (chevron) const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}

/// Round icon button (back, share, bookmark over images).
class PsIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool onImage; // white disc used over photos
  final Color? color;
  final double size;
  const PsIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.onImage = false,
    this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: onImage ? Colors.white : Colors.transparent,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 24, color: color ?? AppColors.text),
        ),
      ),
    );
    return Semantics(button: true, label: tooltip, excludeSemantics: true, child: Tooltip(message: tooltip, child: btn));
  }
}

// ─── TOP BARS & HEADERS ──────────────────────────────────────────────────────

/// Standard top bar: back chevron, optional centred/leading title, optional action.
class PsTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? backLabel; // e.g. "Back"
  final Widget? action;
  final bool centerTitle;
  final VoidCallback? onBack;
  final bool dark; // over the green header
  final bool showBack;

  const PsTopBar({
    super.key,
    this.title,
    this.backLabel,
    this.action,
    this.centerTitle = false,
    this.onBack,
    this.dark = false,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.text;
    final back = showBack
        ? InkWell(
            onTap: onBack ?? () => context.canPop() ? context.pop() : context.go('/home'),
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: fg),
                if (backLabel != null) ...[
                  const SizedBox(width: 6),
                  Text(backLabel!, style: AppText.body.copyWith(color: fg, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(width: 4),
              ]),
            ),
          )
        : const SizedBox(width: 12);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Semantics(button: true, label: 'Back', excludeSemantics: true, child: back),
            if (title != null && !centerTitle) ...[
              const SizedBox(width: 4),
              Expanded(child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: fg))),
            ] else
              const Spacer(),
            if (title != null && centerTitle) ...[
              Expanded(child: Center(child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: fg)))),
            ],
            if (action != null) action! else if (centerTitle) const SizedBox(width: 48),
          ]),
        ),
      ),
    );
  }
}

/// Forest-green header block with rounded lower corners and a soft leaf shape.
class PsGreenHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const PsGreenHeader({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 28)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.sheet)),
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        child: Stack(children: [
          Positioned(
            right: -60,
            top: -30,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.6,
                child: Container(
                  width: 260,
                  height: 340,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(220),
                      bottomRight: Radius.circular(220),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
        ]),
      ),
    );
  }
}

class PsSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const PsSectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Semantics(header: true, child: Text(title, style: AppText.h3))),
      if (action != null) PsLink(action!, onTap: onAction, chevron: true, underline: false),
    ]);
  }
}

// ─── SURFACES ────────────────────────────────────────────────────────────────

class PsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;

  const PsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? AppColors.border),
    );
    final content = Padding(padding: padding, child: child);
    final card = Material(
      color: color ?? AppColors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    if (onTap != null && semanticLabel != null) {
      return Semantics(button: true, label: semanticLabel, child: card);
    }
    return card;
  }
}

class PsIconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;
  const PsIconCircle(this.icon, {super.key, this.size = 48, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? AppColors.primaryPale, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: fg ?? AppColors.primary),
    );
  }
}

class PsPill extends StatelessWidget {
  final String label;
  final PsTone tone;
  final IconData? icon;
  final bool small;
  const PsPill(this.label, {super.key, this.tone = PsTone.success, this.icon, this.small = false});

  @override
  Widget build(BuildContext context) {
    final fg = _toneFg(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12, vertical: small ? 5 : 7),
      decoration: BoxDecoration(color: _toneBg(tone), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
      ]),
    );
  }
}

/// Selectable pill (Rent / Sale / Short stay, bedroom counts, …).
class PsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool removable;
  const PsChip(this.label, {super.key, this.selected = false, this.onTap, this.icon, this.removable = false});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.card,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                Text(label, style: AppText.body.copyWith(color: fg, fontWeight: FontWeight.w600)),
                if (removable) ...[const SizedBox(width: 8), Icon(Icons.close_rounded, size: 18, color: fg)],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-way / multi-way segmented control (Phone | Email, Monthly | Annual…).
class PsSegmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PsSegmented({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.md + 2)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(labels[i],
                        textAlign: TextAlign.center,
                        style: AppText.label.copyWith(
                          color: i == index ? Colors.white : AppColors.text2,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── ROWS ────────────────────────────────────────────────────────────────────

class PsListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? titleColor;
  final EdgeInsets padding;

  const PsListRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.titleColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)]
        else if (icon != null) ...[PsIconCircle(icon!, size: 44), const SizedBox(width: 14)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.title.copyWith(color: titleColor ?? AppColors.text)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: AppText.small),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (onTap != null && chevron) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 26, color: AppColors.text2),
        ],
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 56), child: row)),
    );
  }
}

/// A group of rows inside one card, with hairline dividers between them.
class PsRowGroup extends StatelessWidget {
  final List<Widget> rows;
  const PsRowGroup(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) children.add(const Divider(height: 1, indent: 16, endIndent: 16));
    }
    return PsCard(padding: EdgeInsets.zero, child: Column(children: children));
  }
}

class PsToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const PsToggleRow({super.key, required this.title, this.subtitle, this.icon, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 24, color: AppColors.text2), const SizedBox(width: 16)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppText.title.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null) Text(subtitle!, style: AppText.caption),
                ]),
              ),
              Switch(value: value, onChanged: onChanged),
            ]),
          ),
        ),
      ),
    );
  }
}

enum PsCheck { done, none, pending }

class PsCheckRow extends StatelessWidget {
  final String label;
  final PsCheck state;
  final String? trailing;
  const PsCheckRow(this.label, {super.key, this.state = PsCheck.done, this.trailing});

  @override
  Widget build(BuildContext context) {
    final bg = state == PsCheck.done ? AppColors.primary : AppColors.text3;
    final icon = state == PsCheck.done
        ? Icons.check_rounded
        : state == PsCheck.pending
            ? Icons.more_horiz_rounded
            : Icons.remove_rounded;
    return Semantics(
      label: '$label${trailing != null ? ', $trailing' : ''}${state == PsCheck.done ? ', checked' : ', not checked'}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppText.body)),
          if (trailing != null) Text(trailing!, style: AppText.small),
        ]),
      ),
    );
  }
}

class PsNote extends StatelessWidget {
  final String text;
  final IconData icon;
  final PsTone tone;
  const PsNote(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.tone = PsTone.neutral});

  @override
  Widget build(BuildContext context) {
    final warning = tone == PsTone.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningPale : AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: warning ? const Color(0xFFEBD9A5) : AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: warning ? AppColors.goldDark : AppColors.text2),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.small.copyWith(color: warning ? AppColors.goldDark : AppColors.text2, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ─── FORMS ───────────────────────────────────────────────────────────────────

/// Label above a white field — the form pattern used across the mockups.
class PsField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final int maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? formatters;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final bool readOnly;
  final VoidCallback? onTap;

  const PsField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.formatters,
    this.validator,
    this.initialValue,
    this.focusNode,
    this.autofillHints,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
      ),
      TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        focusNode: focusNode,
        enabled: enabled,
        readOnly: readOnly,
        onTap: onTap,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: obscure ? 1 : maxLines,
        minLines: maxLines > 1 ? (maxLines > 4 ? 4 : maxLines) : 1,
        maxLength: maxLength,
        inputFormatters: formatters,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          prefixIcon: prefix,
          suffixIcon: suffix,
          counterText: maxLength == null ? null : null,
        ),
      ),
      if (helper != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(helper!, style: AppText.caption)),
    ]);
  }
}

class PsDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String? hint;
  const PsDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
      ),
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.text),
        style: AppText.body,
        dropdownColor: AppColors.card,
        decoration: InputDecoration(hintText: hint),
        items: [for (final i in items) DropdownMenuItem<T>(value: i, child: Text(itemLabel(i), overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    ]);
  }
}

class PsStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const PsStepper({super.key, required this.label, required this.value, required this.onChanged, this.min = 0, this.max = 20});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, String tip, VoidCallback? f) => PsIconButton(icon: i, tooltip: tip, onPressed: f, color: f == null ? AppColors.text3 : AppColors.text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Text(label, style: AppText.small.copyWith(fontWeight: FontWeight.w600))),
        btn(Icons.remove_rounded, 'Fewer $label', value > min ? () => onChanged(value - 1) : null),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: AppText.title)),
        btn(Icons.add_rounded, 'More $label', value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }
}

/// Checkbox-style tile used for amenities ("Water", "Prepaid meter" …).
class PsCheckTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const PsCheckTile(this.label, {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: value ? AppColors.primary : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: value ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 22, color: value ? Colors.white : AppColors.text2),
                const SizedBox(width: 8),
                Text(label, style: AppText.label.copyWith(color: value ? Colors.white : AppColors.text)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MEDIA ───────────────────────────────────────────────────────────────────

/// Network image with a stable placeholder — a failed or missing image never
/// collapses the layout.
class PsNetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? radius;
  final IconData placeholderIcon;
  final String? semanticLabel;
  const PsNetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholderIcon = Icons.home_work_outlined,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          width: width,
          height: height,
          color: AppColors.muted,
          alignment: Alignment.center,
          child: Icon(placeholderIcon, size: 32, color: AppColors.text3),
        );
    final u = url;
    Widget img = (u == null || u.isEmpty)
        ? placeholder()
        : CachedNetworkImage(
            imageUrl: u,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) => placeholder(),
            errorWidget: (_, __, ___) => placeholder(),
          );
    if (radius != null) img = ClipRRect(borderRadius: radius!, child: img);
    return Semantics(image: true, label: semanticLabel ?? 'Property photo', excludeSemantics: true, child: img);
  }
}

class PsAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const PsAvatar({super.key, this.url, required this.name, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: PsNetImage(url, width: size, height: size, placeholderIcon: Icons.person_rounded, semanticLabel: '$name profile photo'),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Text(initial, style: AppText.title.copyWith(color: Colors.white, fontSize: size * 0.42)),
    );
  }
}

// ─── STATES ──────────────────────────────────────────────────────────────────

class PsEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? footnote;
  const PsEmpty({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction, this.footnote});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PsIconCircle(icon, size: 72),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: AppText.h3),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: AppText.bodyMuted),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            PsButton(actionLabel!, onPressed: onAction, expand: false),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 16),
            SelectableText(footnote!, textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.text3)),
          ],
        ]),
      ),
    );
  }
}

/// Plain-language, retryable error — never a raw exception.
class PsError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool offline;
  /// Technical reason (for example a Firestore error). Shown small under the
  /// friendly message so a problem can be reported and fixed quickly.
  final Object? details;
  const PsError({super.key, this.message = 'Something went wrong. Please try again.', this.onRetry, this.offline = false, this.details});

  @override
  Widget build(BuildContext context) {
    final raw = details?.toString().trim() ?? '';
    final tech = raw.isEmpty ? null : (raw.length > 220 ? '${raw.substring(0, 220)}…' : raw);
    return PsEmpty(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? "You're offline" : "We couldn't load this",
      message: offline ? 'Check your connection. Saved homes stay available.' : message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      footnote: (tech != null && !offline) ? 'Details: $tech' : null,
    );
  }
}

class PsSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const PsSkeleton({super.key, this.width, this.height = 16, this.radius = 10});

  @override
  State<PsSkeleton> createState() => _PsSkeletonState();
}

class _PsSkeletonState extends State<PsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.muted, const Color(0xFFE3E0D8), _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Card-shaped skeleton for listing feeds.
class PsListingSkeleton extends StatelessWidget {
  const PsListingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const PsCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PsSkeleton(height: 200, radius: 0),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsSkeleton(width: 180, height: 20),
            SizedBox(height: 10),
            PsSkeleton(width: 120),
            SizedBox(height: 14),
            PsSkeleton(width: 220, height: 28, radius: 14),
          ]),
        ),
      ]),
    );
  }
}

// ─── BARS ────────────────────────────────────────────────────────────────────

/// Sticky bottom action area (e.g. "Ask a question" + "Book inspection").
class PsBottomBar extends StatelessWidget {
  final List<Widget> children;
  final bool row;
  const PsBottomBar({super.key, required this.children, this.row = true});

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(row ? Expanded(child: children[i]) : children[i]);
      if (i < children.length - 1) spaced.add(SizedBox(width: row ? 12 : 0, height: row ? 0 : 12));
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: row ? Row(children: spaced) : Column(mainAxisSize: MainAxisSize.min, children: spaced),
        ),
      ),
    );
  }
}

class PsNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool dot;
  const PsNavItem(this.icon, this.activeIcon, this.label, {this.dot = false});
}

/// Bottom navigation: icon over label, green when active. Labels are ≥12px.
class PsNavBar extends StatelessWidget {
  final List<PsNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final bool dark;
  const PsNavBar({super.key, required this.items, required this.index, required this.onTap, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF14141F) : Colors.white;
    final onColor = dark ? Colors.white : AppColors.primary;
    final offColor = dark ? const Color(0xFFB8B8C6) : AppColors.text2;
    final pill = dark ? const Color(0x24FFFFFF) : AppColors.primaryPale;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: dark ? const Color(0xFF2A2A38) : AppColors.border)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: SizedBox(
            height: 62,
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onTap(i),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: i == index ? 62 : 40,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: i == index ? pill : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                            child: Icon(i == index ? items[i].activeIcon : items[i].icon, size: 24, color: i == index ? onColor : offColor),
                          ),
                          if (items[i].dot)
                            Positioned(
                              right: i == index ? 8 : 2,
                              top: 2,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(items[i].label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.1,
                                  color: i == index ? onColor : offColor,
                                  fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                                )),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Numbered step indicator (1 Media — 2 Details — 3 Costs — 4 Review).
class PsSteps extends StatelessWidget {
  final List<String> labels;
  final int current; // 0-based
  const PsSteps({super.key, required this.labels, required this.current});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of ${labels.length}: ${labels[current]}',
      excludeSemantics: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < labels.length; i++) ...[
          Column(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.primary : AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: i < current
                  ? const Icon(Icons.check_rounded, size: 22, color: Colors.white)
                  : Text('${i + 1}', style: AppText.label.copyWith(color: i <= current ? Colors.white : AppColors.text2)),
            ),
            const SizedBox(height: 6),
            Text(labels[i], style: AppText.caption.copyWith(color: i == current ? AppColors.text : AppColors.text3, fontWeight: i == current ? FontWeight.w700 : FontWeight.w500)),
          ]),
          if (i < labels.length - 1)
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 20), child: Divider(color: i < current ? AppColors.primary : AppColors.border2, thickness: 1.5))),
        ],
      ]),
    );
  }
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

void showPsSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.text,
    ));
}

/// Standard horizontal page padding.
const EdgeInsets kPagePadding = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

/// Page scaffold: ivory background, optional top bar and bottom bar, scrollable
/// body with gutters and bottom safe-area padding.
class PsPage extends StatelessWidget {
  final PreferredSizeWidget? topBar;
  final Widget? bottom;
  final List<Widget> children;
  final EdgeInsets padding;
  final Future<void> Function()? onRefresh;
  final Widget? header; // full-bleed widget above the padded list (green header)
  final Color? background;
  const PsPage({
    super.key,
    this.topBar,
    this.bottom,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 32),
    this.onRefresh,
    this.header,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      padding: header == null ? padding : EdgeInsets.zero,
      children: header == null
          ? children
          : [header!, Padding(padding: padding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children))],
    );
    if (onRefresh != null) list = RefreshIndicator(onRefresh: onRefresh!, child: list);
    return Scaffold(
      backgroundColor: background ?? AppColors.surface,
      appBar: topBar,
      body: list,
      bottomNavigationBar: bottom,
    );
  }
}
