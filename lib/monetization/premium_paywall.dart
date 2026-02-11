import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../theme/stirnraten_colors.dart';
import '../utils/effects_quality.dart';
import '../widgets/glass_widgets.dart';
import 'monetization_controller.dart';

enum PaywallTrigger {
  wordLimit,
  aiQuota,
}

Future<void> showPremiumPaywall(
  BuildContext context, {
  required PaywallTrigger trigger,
  String? message,
}) async {
  final effects = EffectsConfig.of(context);
  final blurSigma =
      effects.allowBlur ? effects.blur(high: 10, medium: 7, low: 0) : 0.0;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        child: GlassBackdrop(
          blurSigma: blurSigma,
          enableBlur: effects.allowBlur,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: StirnratenColors.categoryGlass,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: StirnratenColors.categoryBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: _PaywallContent(
              trigger: trigger,
              message: message,
            ),
          ),
        ),
      );
    },
  );
}

class _PaywallContent extends StatelessWidget {
  final PaywallTrigger trigger;
  final String? message;

  const _PaywallContent({
    required this.trigger,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final monetization = context.watch<MonetizationController>();
    final isPremium = monetization.isPremium;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StirnratenColors.categoryPrimary.withValues(alpha: 0.18),
                border: Border.all(
                  color:
                      StirnratenColors.categoryPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: StirnratenColors.categoryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Premium freischalten',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryText,
                ),
              ),
            ),
            _IconCloseButton(onTap: () => Navigator.pop(context)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Einmalig 4,99 €',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: StirnratenColors.categoryMuted,
          ),
        ),
        if (message != null && message!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: trigger == PaywallTrigger.aiQuota
                  ? StirnratenColors.categoryPrimary.withValues(alpha: 0.12)
                  : const Color(0xFFEF4444).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: trigger == PaywallTrigger.aiQuota
                    ? StirnratenColors.categoryPrimary.withValues(alpha: 0.20)
                    : const Color(0xFFEF4444).withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              message!.trim(),
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: StirnratenColors.categoryText,
                height: 1.25,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const _Bullet('Unbegrenzte KI-Listen'),
        const SizedBox(height: 6),
        const _Bullet('Bis zu 100 Wörter pro Liste'),
        const SizedBox(height: 6),
        const _Bullet('Keine Limits mehr'),
        const SizedBox(height: 14),
        if (monetization.iapStatusMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              monetization.iapStatusMessage!,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _SecondaryPillButton(
                label: 'Käufe wiederherstellen',
                onTap: monetization.isPurchaseBusy
                    ? null
                    : () async {
                        await monetization.restorePurchases();
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PrimaryPillButton(
                label: isPremium ? 'Premium aktiv' : 'Premium kaufen',
                icon: Icons.lock_open_rounded,
                onTap: monetization.isPurchaseBusy ||
                        isPremium ||
                        !monetization.canAttemptPurchase
                    ? null
                    : () async {
                        final ok = await monetization.buyPremium();
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context);
                        }
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Später',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: StirnratenColors.categoryMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A34A)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: StirnratenColors.categoryText,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _IconCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.close_rounded,
          color: StirnratenColors.categoryText,
          size: 22,
        ),
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _PrimaryPillButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: StirnratenColors.categoryPrimary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: StirnratenColors.categoryPrimary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: StirnratenColors.categoryText, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.fredoka(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: StirnratenColors.categoryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SecondaryPillButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: StirnratenColors.categoryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
