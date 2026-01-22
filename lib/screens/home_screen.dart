import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/sound_service.dart';
import '../utils/effects_quality.dart';
import '../widgets/glass_widgets.dart';
import 'stirnraten_screen.dart';

const Color _homePrimary = Color(0xFF21D4EA);
const Color _homeBackgroundTop = Color(0xFFFFE277);
const Color _homeBackgroundMid = Color(0xFFFFB866);
const Color _homeBackgroundBottom = Color(0xFFF25B8F);
const Color _homeCardSurface = Color(0xB3FFFFFF);
const Color _homeCardBorder = Color(0x8CFFFFFF);
const Color _homeText = Color(0xFF1E293B);
const Color _homeMuted = Color(0xFF3B4A5A);
const double _homeCardRadius = 48;

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
      duration: const Duration(seconds: 18),
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
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.15, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
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
    const verticalPadding = 16.0;
    final effects = EffectsConfig.of(context);
    final enableMotion =
        effects.quality == EffectsQuality.high && !effects.reduceMotion;

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: _AnimatedBackground(
              controller: _bgController,
              effects: effects,
              enableMotion: enableMotion,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = min(constraints.maxWidth, 420.0);
                final availableHeight = constraints.maxHeight;
                final cardHeight =
                    (availableHeight * 0.5).clamp(320.0, 460.0);
                final headerSpacing = availableHeight < 700 ? 16.0 : 22.0;
                final footerSpacing = availableHeight < 700 ? 12.0 : 18.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeTransition(
                            opacity: _topFade,
                            child: const _TopBar(),
                          ),
                          SizedBox(height: headerSpacing),
                          SlideTransition(
                            position: _heroSlide,
                            child: FadeTransition(
                              opacity: _heroFade,
                              child: SizedBox(
                                height: cardHeight,
                                child: _StartCard(
                                  pulse: _pulse,
                                  floatController: _bgController,
                                  effects: effects,
                                  enableMotion: enableMotion,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SlideTransition(
                            position: _ctaSlide,
                            child: FadeTransition(
                              opacity: _ctaFade,
                              child: _StartButton(
                                onPressed: _startGame,
                              ),
                            ),
                          ),
                          SizedBox(height: footerSpacing),
                          FadeTransition(
                            opacity: _tipFade,
                            child: Text.rich(
                              TextSpan(
                                text: 'Tipp: Kippen für ',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _homeText.withValues(alpha: 0.65),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'richtig',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF22C55E),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ', zurück für ',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w600,
                                      color: _homeText.withValues(alpha: 0.65),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'passen',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
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
                style: GoogleFonts.fredoka(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _homeText,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'PARTY GAME',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: _homeText.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const _TopIcon(icon: Icons.person_rounded),
      ],
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;

  const _TopIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma = effects.blur(high: 18, medium: 12, low: 0);
    return GlassBackdrop(
      blurSigma: blurSigma,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: _homeText.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> floatController;
  final EffectsConfig effects;
  final bool enableMotion;

  const _StartCard({
    required this.pulse,
    required this.floatController,
    required this.effects,
    required this.enableMotion,
  });

  @override
  Widget build(BuildContext context) {
    final blurSigma = effects.blur(high: 20, medium: 16, low: 0);
    final shadowBlur = effects.shadowBlur(high: 26, medium: 20, low: 12);

    return GlassBackdrop(
      blurSigma: blurSigma,
      borderRadius: BorderRadius.circular(_homeCardRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_homeCardRadius),
          color: _homeCardSurface,
          border: Border.all(color: _homeCardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: shadowBlur,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_homeCardRadius),
                  ),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFA83A),
                      Color(0xFFF25B8F),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _ModePill(
                      pulse: pulse,
                      enableMotion: enableMotion,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFD34A),
                              Color(0xFFFF9E2C),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          Icons.smartphone_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 42,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: _SmileyBadge(
                          floatController: floatController,
                          enableMotion: enableMotion,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Setz das Handy\nan die Stirn.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: _homeText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Das Team erklärt.\nDu rätst.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: _homeMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmileyBadge extends StatelessWidget {
  final Animation<double> floatController;
  final bool enableMotion;

  const _SmileyBadge({
    required this.floatController,
    required this.enableMotion,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC1D9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF25B8F).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.sentiment_satisfied_rounded,
        size: 16,
        color: const Color(0xFFE11D74),
      ),
    );

    if (!enableMotion) {
      return badge;
    }

    return AnimatedBuilder(
      animation: floatController,
      builder: (context, child) {
        final t = floatController.value * pi * 2;
        final drift = sin(t) * 3;
        return Transform.translate(
          offset: Offset(0, drift),
          child: child,
        );
      },
      child: badge,
    );
  }
}

class _ModePill extends StatelessWidget {
  final Animation<double> pulse;
  final bool enableMotion;

  const _ModePill({
    required this.pulse,
    required this.enableMotion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (enableMotion)
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(pulse.value);
                      final scale = lerpDouble(1.0, 1.8, t)!;
                      final opacity = lerpDouble(0.25, 0.0, t)!;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: opacity),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'PARTY MODUS',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _homeText,
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
          height: 64,
          decoration: BoxDecoration(
            color: _homePrimary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _homePrimary.withValues(alpha: 0.4),
                blurRadius: 26,
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
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _homeText,
                  letterSpacing: 0.2,
                ),
              ),
              Positioned(
                right: 10,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: _homeText,
                    size: 24,
                  ),
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
  final bool enableMotion;

  const _AnimatedBackground({
    required this.controller,
    required this.effects,
    required this.enableMotion,
  });

  @override
  Widget build(BuildContext context) {
    final blurPrimary = effects.shadowBlur(high: 140, medium: 110, low: 70);
    final blurSecondary = effects.shadowBlur(high: 160, medium: 120, low: 80);
    final blurTertiary = effects.shadowBlur(high: 120, medium: 90, low: 60);
    final spread = effects.shadowBlur(high: 10, medium: 8, low: 4);

    Widget buildStack(double driftX, double driftY) {
      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _homeBackgroundTop,
                    _homeBackgroundMid,
                    _homeBackgroundBottom,
                  ],
                ),
              ),
            ),
          ),
          _GlowOrb(
            size: 300,
            color: const Color(0xFFFFF1A6).withValues(alpha: 0.35),
            offset: Offset(100 + driftX, -140 + driftY),
            alignment: Alignment.topRight,
            blurRadius: blurPrimary,
            spreadRadius: spread,
          ),
          _GlowOrb(
            size: 340,
            color: const Color(0xFFFF9FCE).withValues(alpha: 0.28),
            offset: Offset(-140 + driftX, 160 + driftY),
            alignment: Alignment.centerLeft,
            blurRadius: blurSecondary,
            spreadRadius: spread,
          ),
          _GlowOrb(
            size: 240,
            color: const Color(0xFF7DD3FC).withValues(alpha: 0.22),
            offset: Offset(60 + driftY, 220 - driftX),
            alignment: Alignment.bottomRight,
            blurRadius: blurTertiary,
            spreadRadius: spread,
          ),
          _DecorIcon(
            controller: controller,
            icon: Icons.music_note_rounded,
            size: 24,
            color: Colors.white.withValues(alpha: 0.55),
            alignment: Alignment.topLeft,
            offset: const Offset(16, 120),
            phase: 0.2,
          ),
          _DecorIcon(
            controller: controller,
            icon: Icons.star_rounded,
            size: 22,
            color: Colors.white.withValues(alpha: 0.45),
            alignment: Alignment.centerRight,
            offset: const Offset(-28, -20),
            phase: 1.4,
          ),
          _DecorIcon(
            controller: controller,
            icon: Icons.bolt_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.35),
            alignment: Alignment.centerLeft,
            offset: const Offset(10, 120),
            phase: 2.1,
          ),
          _DecorIcon(
            controller: controller,
            icon: Icons.change_history_rounded,
            size: 18,
            color: const Color(0xFF34D399).withValues(alpha: 0.6),
            alignment: Alignment.topCenter,
            offset: const Offset(0, 80),
            phase: 0.8,
          ),
          _DecorDot(
            controller: controller,
            size: 12,
            color: const Color(0xFF60A5FA).withValues(alpha: 0.65),
            alignment: Alignment.bottomLeft,
            offset: const Offset(40, -120),
            phase: 2.6,
          ),
          _DecorDot(
            controller: controller,
            size: 14,
            color: const Color(0xFFFBBF24).withValues(alpha: 0.7),
            alignment: Alignment.centerRight,
            offset: const Offset(-90, 40),
            phase: 1.8,
          ),
          _DecorDiamond(
            controller: controller,
            size: 16,
            color: const Color(0xFFF472B6).withValues(alpha: 0.6),
            alignment: Alignment.topLeft,
            offset: const Offset(90, 180),
            phase: 1.1,
          ),
        ],
      );
    }

    if (!enableMotion) {
      return buildStack(0, 0);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value * pi * 2;
        final driftX = sin(t) * 12;
        final driftY = cos(t) * 10;
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

class _DecorIcon extends StatelessWidget {
  final Animation<double> controller;
  final IconData icon;
  final double size;
  final Color color;
  final Alignment alignment;
  final Offset offset;
  final double phase;

  const _DecorIcon({
    required this.controller,
    required this.icon,
    required this.size,
    required this.color,
    required this.alignment,
    required this.offset,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = controller.value * pi * 2 + phase;
          final drift = Offset(sin(t) * 6, cos(t) * 6);
          return Transform.translate(
            offset: offset + drift,
            child: child,
          );
        },
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _DecorDot extends StatelessWidget {
  final Animation<double> controller;
  final double size;
  final Color color;
  final Alignment alignment;
  final Offset offset;
  final double phase;

  const _DecorDot({
    required this.controller,
    required this.size,
    required this.color,
    required this.alignment,
    required this.offset,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = controller.value * pi * 2 + phase;
          final drift = Offset(sin(t) * 5, cos(t) * 5);
          return Transform.translate(
            offset: offset + drift,
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DecorDiamond extends StatelessWidget {
  final Animation<double> controller;
  final double size;
  final Color color;
  final Alignment alignment;
  final Offset offset;
  final double phase;

  const _DecorDiamond({
    required this.controller,
    required this.size,
    required this.color,
    required this.alignment,
    required this.offset,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = controller.value * pi * 2 + phase;
          final drift = Offset(sin(t) * 4, cos(t) * 4);
          return Transform.translate(
            offset: offset + drift,
            child: child,
          );
        },
        child: Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
