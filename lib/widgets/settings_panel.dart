import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../engine/stirnraten_engine.dart';
import '../theme/stirnraten_colors.dart';
import '../utils/effects_quality.dart';

class SettingsPanel extends StatelessWidget {
  final int selectedTime;
  final ValueChanged<int> onTimeChanged;
  final GameMode selectedMode;
  final ValueChanged<GameMode> onModeChanged;
  final bool isPremium;
  final VoidCallback onPremiumTap;

  const SettingsPanel({
    super.key,
    required this.selectedTime,
    required this.onTimeChanged,
    required this.selectedMode,
    required this.onModeChanged,
    required this.isPremium,
    required this.onPremiumTap,
  });

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final shadowBlur = effects.shadowBlur(high: 16, medium: 12, low: 8);
    const timeOptions = [
      _SegmentedOption<int>(value: 30, label: '30s'),
      _SegmentedOption<int>(value: 60, label: '60s'),
      _SegmentedOption<int>(value: 90, label: '90s'),
      _SegmentedOption<int>(value: 120, label: '120s'),
      _SegmentedOption<int>(value: 150, label: '150s'),
    ];

    final modeOptions = [
      const _SegmentedOption<GameMode>(
        value: GameMode.classic,
        label: 'Klassisch',
      ),
      _SegmentedOption<GameMode>(
        value: GameMode.suddenDeath,
        label: 'Sudden',
        isLocked: !isPremium,
      ),
      _SegmentedOption<GameMode>(
        value: GameMode.hardcore,
        label: 'Hardcore',
        isLocked: !isPremium,
      ),
      _SegmentedOption<GameMode>(
        value: GameMode.drinking,
        label: 'Trinkspiel',
        isLocked: !isPremium,
      ),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StirnratenColors.categoryGlass,
          borderRadius: BorderRadius.circular(categoryCardRadius),
          border: Border.all(color: StirnratenColors.categoryBorder, width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.7),
              Colors.white.withValues(alpha: 0.45),
            ],
          ),
          boxShadow: shadowBlur > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spielzeit',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: StirnratenColors.categoryMuted,
              ),
            ),
            const SizedBox(height: 8),
            _SegmentedControl<int>(
              options: timeOptions,
              value: selectedTime,
              onChanged: onTimeChanged,
            ),
            const SizedBox(height: 12),
            Text(
              'Modus',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: StirnratenColors.categoryMuted,
              ),
            ),
            const SizedBox(height: 8),
            _SegmentedControl<GameMode>(
              options: modeOptions,
              value: selectedMode,
              onChanged: onModeChanged,
              onLockedTap: onPremiumTap,
            ),
            if (selectedMode == GameMode.drinking && isPremium) ...[
              const SizedBox(height: 10),
              Text(
                'Optionaler Party-Modus. Bitte verantwortungsvoll.',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: StirnratenColors.categoryMuted.withValues(alpha: 0.75),
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedOption<T> {
  final T value;
  final String label;
  final bool isLocked;

  const _SegmentedOption({
    required this.value,
    required this.label,
    this.isLocked = false,
  });
}

class _SegmentedControl<T> extends StatelessWidget {
  final List<_SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final VoidCallback? onLockedTap;

  const _SegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((option) {
        final locked = option.isLocked;
        final selected = option.value == value && !locked;
        final backgroundColor = selected
            ? StirnratenColors.categoryPrimary
            : Colors.white.withValues(alpha: locked ? 0.4 : 0.7);
        final textColor = selected
            ? StirnratenColors.categoryText
            : StirnratenColors.categoryMuted.withValues(
                alpha: locked ? 0.45 : 0.75,
              );

        return GestureDetector(
          onTap: () {
            if (locked) {
              onLockedTap?.call();
              return;
            }
            onChanged(option.value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? StirnratenColors.categoryPrimary
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.label,
                  style: GoogleFonts.nunito(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: textColor,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

