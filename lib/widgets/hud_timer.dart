import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/effects_quality.dart';

class HudTimerRow extends StatelessWidget {
  final ValueListenable<String> timerText;
  final ValueListenable<bool> timerBlink;
  final int score;
  final VoidCallback? onExitTap;

  const HudTimerRow({
    super.key,
    required this.timerText,
    required this.timerBlink,
    required this.score,
    this.onExitTap,
  });

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([timerText, timerBlink]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedBuilder(
          animation: merged,
          builder: (context, _) {
            return HudChip(
              value: timerText.value,
              icon: Icons.access_time_rounded,
              isBlinking: timerBlink.value,
            );
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onExitTap != null) ...[
              _HudExitChip(onTap: onExitTap!),
              const SizedBox(width: 8),
            ],
            HudChip(
              label: 'PUNKTE',
              value: '$score',
              alignEnd: true,
              inlineLabel: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _HudExitChip extends StatelessWidget {
  final VoidCallback onTap;

  const _HudExitChip({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const chipColor = Color(0xFFF6B62D);
    final effects = EffectsConfig.of(context);
    final shadowBlur = effects.shadowBlur(high: 10, medium: 6, low: 0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: shadowBlur > 0
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.32),
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: const Icon(
          Icons.meeting_room_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class HudChip extends StatelessWidget {
  final String? label;
  final String value;
  final bool alignEnd;
  final IconData? icon;
  final bool isBlinking;
  final bool inlineLabel;

  const HudChip({
    super.key,
    required this.value,
    this.label,
    this.alignEnd = false,
    this.icon,
    this.isBlinking = false,
    this.inlineLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    const chipColor = Color(0xFFF6B62D);
    final backgroundColor = isBlinking ? const Color(0xFFEF4444) : chipColor;
    final effects = EffectsConfig.of(context);
    final shadowBlur = effects.shadowBlur(high: 10, medium: 6, low: 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: shadowBlur > 0
            ? [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.4),
                  blurRadius: shadowBlur,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
          ],
          if (inlineLabel && label != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: textAlign,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
