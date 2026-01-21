import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/sound_service.dart';
import 'stirnraten_screen.dart';

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
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.15, 0.8, curve: Curves.easeOutCubic),
    ));
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

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

    return Scaffold(
      body: Stack(
        children: [
          _AnimatedBackground(controller: _bgController),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = min(constraints.maxWidth, 420.0);
                final minHeight = max(
                  0.0,
                  constraints.maxHeight - (verticalPadding * 2),
                );
                final heroHeight = min(
                  440.0,
                  max(320.0, constraints.maxHeight * 0.52),
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
                                      child: _HeroCard(pulse: _pulse),
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
                                        color: Colors.white.withOpacity(0.45),
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
                style: GoogleFonts.oswald(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              Text(
                'Party Game',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: Colors.white.withOpacity(0.55),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: Colors.white.withOpacity(0.85),
      ),
    );
  }
}

class _HeroCard extends StatefulWidget {
  final Animation<double> pulse;

  const _HeroCard({required this.pulse});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(28);
    final innerRadius = BorderRadius.circular(26);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: outerRadius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.6),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: const Color(0xFFF97316).withOpacity(0.18),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(1.6),
            decoration: BoxDecoration(
              borderRadius: outerRadius,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFB347),
                  Color(0xFF38BDF8),
                  Color(0xFFFB7185),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipRRect(
              borderRadius: innerRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/stirnraten_image.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0B0E16).withOpacity(0.18),
                            const Color(0xFF0B0E16).withOpacity(0.85),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -70,
                    right: -40,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFB347).withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: innerRadius.bottomLeft,
                        bottomRight: innerRadius.bottomRight,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.0),
                                Colors.black.withOpacity(0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ModePill(pulse: widget.pulse),
                        const SizedBox(height: 14),
                        Text(
                          'Setz das Handy\nan die Stirn.',
                          style: GoogleFonts.oswald(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                            letterSpacing: 0.4,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Das Team erklärt. Du rätst.',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: Colors.white.withOpacity(0.68),
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                  color: const Color(0xFF4ADE80).withOpacity(opacity),
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
              letterSpacing: 0.8,
              color: Colors.white.withOpacity(0.9),
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
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF4D6D),
                  Color(0xFFFFB347),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A34).withOpacity(0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: borderRadius,
                      ),
                    ),
                  ),
                ),
                Stack(
                  children: [
                    Center(
                      child: Text(
                        'Runde starten',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 0,
                      bottom: 0,
                      child: AnimatedSlide(
                        offset: _hovered ? const Offset(0.08, 0) : Offset.zero,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value * pi * 2;
        final driftX = sin(t) * 18;
        final driftY = cos(t) * 14;

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.9),
                    radius: 1.3,
                    colors: [
                      Color(0xFF1B1F2E),
                      Color(0xFF0B0E16),
                    ],
                    stops: [0.0, 0.65],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0B0E16).withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
            _GlowOrb(
              size: 420,
              color: const Color(0xFFFB7185).withOpacity(0.25),
              offset: Offset(-120 + driftX, -110 + driftY),
              alignment: Alignment.topLeft,
              blurRadius: 110,
            ),
            _GlowOrb(
              size: 380,
              color: const Color(0xFF38BDF8).withOpacity(0.22),
              offset: Offset(130 - driftX, 60 + driftY),
              alignment: Alignment.topRight,
              blurRadius: 120,
            ),
            _GlowOrb(
              size: 520,
              color: const Color(0xFFF97316).withOpacity(0.18),
              offset: Offset(40 + driftY, 170 - driftX),
              alignment: Alignment.bottomLeft,
              blurRadius: 140,
            ),
          ],
        );
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
    this.blurRadius = 100,
    this.spreadRadius = 10,
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
                color: color.withOpacity(0.6),
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
