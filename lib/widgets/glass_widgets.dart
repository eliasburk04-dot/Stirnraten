import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wiederverwendbare Glassmorphism Card
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;

  const GlassCard({
    super.key,
    required this.child,
    this.height,
    this.padding,
    this.onTap,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: gradientColors != null
            ? [
                BoxShadow(
                  color: gradientColors![0].withAlpha(40),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withAlpha(15),
                  Colors.white.withAlpha(8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha(25),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return _GlassCardTappable(
        onTap: onTap!,
        child: card,
      );
    }

    return card;
  }
}

class _GlassCardTappable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _GlassCardTappable({
    required this.onTap,
    required this.child,
  });

  @override
  State<_GlassCardTappable> createState() => _GlassCardTappableState();
}

class _GlassCardTappableState extends State<_GlassCardTappable> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Moderner Glas-Button
class GlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;
  final List<Color>? gradientColors;
  final bool isFullWidth;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.icon,
    this.gradientColors,
    this.isFullWidth = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final gradientColors = widget.gradientColors ??
        [
          const Color(0xFF7C3AED),
          const Color(0xFFEC4899),
        ];

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Container(
            width: widget.isFullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(
            horizontal: widget.isFullWidth ? 32 : 40,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: !widget.isPrimary
                ? Border.all(
                    color: Colors.white.withAlpha(51),
                    width: 1.5,
                  )
                : null,
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: gradientColors[0].withAlpha(77),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
              ],
              Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
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

/// Modernes Input-Feld im Glas-Stil
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool autofocus;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;

  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.maxLength,
    this.keyboardType,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.style,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(204),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(25),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                maxLength: maxLength,
                keyboardType: keyboardType,
                autofocus: autofocus,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                inputFormatters: inputFormatters,
                textAlign: textAlign,
                textCapitalization: textCapitalization,
                style: style ??
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(102),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  counterText: '',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen Overlay mit Blur für Feedback
class GlassOverlay extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? text;

  const GlassOverlay({
    super.key,
    required this.color,
    required this.icon,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: color.withAlpha(204),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 120,
                color: Colors.white,
              ),
              if (text != null) ...[
                const SizedBox(height: 24),
                Text(
                  text!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Moderner Dark Background mit Gradient
class ModernBackground extends StatelessWidget {
  final Widget child;

  const ModernBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A0A12),
            Color(0xFF14141E),
            Color(0xFF1A1A28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}
