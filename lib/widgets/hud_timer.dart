import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/effects_quality.dart';

class HudTimerRow extends StatelessWidget {
  final ValueListenable<String> timerText;
  final int score;

  const HudTimerRow({
    super.key,
    required this.timerText,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: timerText,
          builder: (context, value, _) {
            return HudChip(
              value: value,
              icon: Icons.access_time_rounded,
            );
          },
        ),
        HudChip(
          label: 'SCORE',
          value: '$score',
          alignEnd: true,
        ),
      ],
    );
  }
}

class HudChip extends StatelessWidget {
  final String? label;
  final String value;
  final bool alignEnd;
  final IconData? icon;

  const HudChip({
    super.key,
    required this.value,
    this.label,
    this.alignEnd = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    const chipColor = Color(0xFFF6B62D);
    final effects = EffectsConfig.of(context);
    final shadowBlur = effects.shadowBlur(high: 10, medium: 6, low: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: shadowBlur > 0
            ? [
                BoxShadow(
                  color: chipColor.withValues(alpha: 0.35),
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
