import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/words.dart';
import '../theme/stirnraten_colors.dart';
import '../utils/effects_quality.dart';

class CategoryCardData {
  const CategoryCardData({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.icon,
    this.tags = const <String>[],
    this.isNsfw = false,
    this.difficulty,
    this.progress,
    this.isOwnWords = false,
  });

  final StirnratenCategory category;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final IconData? icon;
  final List<String> tags;
  final bool isNsfw;
  final String? difficulty;
  final double? progress;
  final bool isOwnWords;
}

class CategoryCard extends StatefulWidget {
  final CategoryCardData data;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final glowBlur = effects.shadowBlur(high: 18, medium: 14, low: 8);
    final accent = widget.data.accentColor ?? StirnratenColors.categoryPrimary;
    final glowAlpha = effects.shadowAlpha(
      high: widget.isSelected ? 0.22 : 0.1,
      medium: widget.isSelected ? 0.16 : 0.06,
      low: 0,
    );
    final borderColor = widget.isSelected
        ? accent.withValues(alpha: 0.8)
        : StirnratenColors.categoryBorder;
    final scale = _pressed ? 0.96 : (widget.isSelected ? 1.02 : 1.0);
    final showGlow = widget.isSelected;

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: StirnratenColors.categoryGlass,
              borderRadius: BorderRadius.circular(categoryCardRadius),
              border: Border.all(
                color: borderColor,
                width: widget.isSelected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: glowBlur,
                  offset: const Offset(0, 10),
                ),
                if (showGlow)
                  BoxShadow(
                    color: accent.withValues(alpha: glowAlpha),
                    blurRadius: glowBlur + 4,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryIconBadge(
                      icon: widget.data.icon,
                      accent: accent,
                    ),
                    const Spacer(),
                    if (widget.data.isNsfw || widget.isSelected)
                      Wrap(
                        spacing: 6,
                        children: [
                          if (widget.data.isNsfw)
                            const _CategoryBadge(
                              label: '18+',
                              background: Color(0xFFB91C1C),
                              textColor: Colors.white,
                            ),
                          if (widget.isSelected)
                            const _CategoryBadge(
                              label: 'SELECTED',
                              background: StirnratenColors.categoryPrimary,
                              textColor: StirnratenColors.categoryText,
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.data.title,
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StirnratenColors.categoryText,
                    letterSpacing: 0.2,
                  ),
                ),
                if (widget.data.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.data.subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          StirnratenColors.categoryMuted.withValues(alpha: 0.75),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
                if (widget.data.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.data.tags
                        .map(
                          (tag) => _TagChip(
                            label: tag,
                            color: accent,
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (widget.data.progress != null || widget.data.difficulty != null)
                  ...[
                    const SizedBox(height: 12),
                    _CategoryProgress(
                      progress: widget.data.progress,
                      difficulty: widget.data.difficulty,
                      accent: accent,
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIconBadge extends StatelessWidget {
  final IconData? icon;
  final Color accent;

  const _CategoryIconBadge({
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: icon == null
          ? const SizedBox.shrink()
          : Icon(
              icon,
              color: accent,
              size: 24,
            ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _CategoryBadge({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: StirnratenColors.categoryText,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CategoryProgress extends StatelessWidget {
  final double? progress;
  final String? difficulty;
  final Color accent;

  const _CategoryProgress({
    required this.progress,
    required this.difficulty,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final value = (progress ?? 0.0).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.55),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (difficulty != null) ...[
          const SizedBox(width: 8),
          Text(
            difficulty!,
            style: GoogleFonts.nunito(
              color: StirnratenColors.categoryMuted.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ],
    );
  }
}
