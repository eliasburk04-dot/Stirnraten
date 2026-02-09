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

  const SettingsPanel({
    super.key,
    required this.selectedTime,
    required this.onTimeChanged,
    required this.selectedMode,
    required this.onModeChanged,
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
      const _SegmentedOption<GameMode>(
        value: GameMode.suddenDeath,
        label: 'K.-o.',
      ),
      const _SegmentedOption<GameMode>(
        value: GameMode.hardcore,
        label: 'Schwer',
      ),
      const _SegmentedOption<GameMode>(
        value: GameMode.drinking,
        label: 'Trinkspiel',
      ),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E8),
          borderRadius: BorderRadius.circular(categoryCardRadius),
          border: Border.all(
            color: const Color(0xFFF8E6D5),
            width: 1.2,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF9F2),
              Color(0xFFFCECDD),
            ],
          ),
          boxShadow: shadowBlur > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: shadowBlur + 4,
                    offset: const Offset(0, 12),
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
            ),
            if (selectedMode == GameMode.drinking) ...[
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

  const _SegmentedOption({
    required this.value,
    required this.label,
  });
}

class _SegmentedControl<T> extends StatelessWidget {
  final List<_SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const _SegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((option) {
        final selected = option.value == value;
        final backgroundColor = selected
            ? StirnratenColors.categoryPrimary
            : const Color(0xFFF4E7DB);
        final textColor = selected
            ? StirnratenColors.categoryText
            : StirnratenColors.categoryMuted.withValues(alpha: 0.75);

        return GestureDetector(
          onTap: () {
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
                    : const Color(0xFFE5D2C3),
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
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
