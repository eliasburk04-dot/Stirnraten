import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/sound_service.dart';
import '../utils/effects_quality.dart';
import '../widgets/glass_widgets.dart';
import 'stirnraten_screen.dart';

const Color _homePrimary = Color(0xFF38BDF8);
const Color _homeBackground = Color(0xFF0B0F1A);
const Color _homeSurface = Color(0xFF141A26);
const Color _homeGlass = Color(0x66141A26);
const Color _homeBorder = Color(0x14FFFFFF);
const double _homeCardRadius = 24;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _bgController;
  late final AnimationController _pulseController;
  late final Animation<double> _topFade;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;
  late final Animation<double> _tipFade;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _topFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _heroFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.15, 0.8, curve: Curves.easeOut),
    );
    _ctaFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _tipFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.15, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame() {
    context.read<SoundService>().playClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StirnratenScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 24.0;
    const verticalPadding = 24.0;
    final effects = EffectsConfig.of(context);

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: _AnimatedBackground(
              controller: _bgController,
              effects: effects,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = min(constraints.maxWidth, 420.0);
                final minHeight = max(
                  0.0,
                  constraints.maxHeight - (verticalPadding * 2),
                );
                final heroHeight = min(
                  520.0,
                  max(320.0, constraints.maxHeight * 0.6),
                );

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FadeTransition(
                                  opacity: _topFade,
                                  child: const _TopBar(),
                                ),
                                const SizedBox(height: 20),
                                SlideTransition(
                                  position: _heroSlide,
                                  child: FadeTransition(
                                    opacity: _heroFade,
                                      child: SizedBox(
                                        height: heroHeight,
                                        child: _StartCard(
                                          pulse: _pulse,
                                          effects: effects,
                                        ),
                                      ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SlideTransition(
                                    position: _ctaSlide,
                                    child: FadeTransition(
                                      opacity: _ctaFade,
                                      child: _StartButton(
                                        onPressed: _startGame,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FadeTransition(
                                    opacity: _tipFade,
                                    child: Text(
                                      'Tipp: Kippen für richtig, zurück für passen.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stirnraten',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: Colors.white,
                ),
              ),
              Text(
                'Party Game',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const _TopIcon(icon: Icons.person),
      ],
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;

  const _TopIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _homeGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

class _StartCard extends StatefulWidget {
  final Animation<double> pulse;
  final EffectsConfig effects;

  const _StartCard({
    required this.pulse,
    required this.effects,
  });

  @override
  State<_StartCard> createState() => _StartCardState();
}

class _StartCardState extends State<_StartCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _hovered ? 1.02 : 1.0;
    final blurSigma = widget.effects.blur(high: 8, medium: 4, low: 0);
    final shadowBlur = widget.effects.shadowBlur(high: 20, medium: 14, low: 8);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: GlassBackdrop(
          blurSigma: blurSigma,
          borderRadius: BorderRadius.circular(_homeCardRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_homeCardRadius),
              border: Border.all(color: _homeBorder),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: _homePrimary.withValues(alpha: 0.18),
                        blurRadius: shadowBlur,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/stirnraten_image.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModePill(pulse: widget.pulse),
                      const SizedBox(height: 16),
                      Text(
                        'Setz das Handy\nan die Stirn.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Das Team erkl\u00e4rt. Du r\u00e4tst.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
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

class _ModePill extends StatelessWidget {
  final Animation<double> pulse;

  const _ModePill({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _homeSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(pulse.value);
              final size = lerpDouble(6, 8, t)!;
              final opacity = lerpDouble(0.6, 1.0, t)!;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Party Modus',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _StartButton({required this.onPressed});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _homePrimary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _homePrimary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Runde starten',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _homeBackground,
                ),
              ),
              Positioned(
                right: 18,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: _homeBackground,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final EffectsConfig effects;

  const _AnimatedBackground({
    required this.controller,
    required this.effects,
  });

  @override
  Widget build(BuildContext context) {
    final blurPrimary = effects.shadowBlur(high: 120, medium: 90, low: 60);
    final blurSecondary = effects.shadowBlur(high: 140, medium: 100, low: 70);
    final blurTertiary = effects.shadowBlur(high: 110, medium: 80, low: 50);
    final spread = effects.shadowBlur(high: 10, medium: 8, low: 4);

    Widget buildStack(double driftX, double driftY) {
      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _homeBackground,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _homeBackground,
                    _homeSurface.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          _GlowOrb(
            size: 260,
            color: _homePrimary.withValues(alpha: 0.16),
            offset: Offset(80 + driftX, -120 + driftY),
            alignment: Alignment.topRight,
            blurRadius: blurPrimary,
            spreadRadius: spread,
          ),
          _GlowOrb(
            size: 300,
            color: const Color(0xFF4ADE80).withValues(alpha: 0.16),
            offset: Offset(-120 + driftX, 160 + driftY),
            alignment: Alignment.bottomLeft,
            blurRadius: blurSecondary,
            spreadRadius: spread,
          ),
          _GlowOrb(
            size: 220,
            color: const Color(0xFF60A5FA).withValues(alpha: 0.14),
            offset: Offset(-80 + driftY, -40 - driftX),
            alignment: Alignment.topLeft,
            blurRadius: blurTertiary,
            spreadRadius: spread,
          ),
        ],
      );
    }

    if (effects.quality == EffectsQuality.low) {
      return buildStack(0, 0);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value * pi * 2;
        final driftX = sin(t) * 14;
        final driftY = cos(t) * 12;
        return buildStack(driftX, driftY);
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final Offset offset;
  final Alignment alignment;
  final double blurRadius;
  final double spreadRadius;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.offset,
    required this.alignment,
    required this.blurRadius,
    required this.spreadRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
