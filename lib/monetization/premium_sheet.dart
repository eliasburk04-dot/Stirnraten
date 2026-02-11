import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'monetization_controller.dart';
import 'monetization_limits.dart';

Future<void> showPremiumSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _PremiumSheet(),
  );
}

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet();

  @override
  Widget build(BuildContext context) {
    final monetization = context.watch<MonetizationController>();
    final usage = monetization.localAiUsageToday();
    final subtitle = monetization.isPremium
        ? 'Aktiv'
        : 'Nicht aktiv • KI heute: ${usage.remaining} frei';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF10121B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 26,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Premium',
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            const _FeatureRow(
              icon: Icons.auto_awesome_rounded,
              title: 'Unbegrenzte KI-Listen',
              subtitle:
                  'Free: ${MonetizationLimits.freeDailyAiGenerations} pro Tag',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.list_alt_rounded,
              title: 'Bis zu 100 Wörter pro Liste',
              subtitle: 'Free: ${MonetizationLimits.freeMaxWordsPerList}',
            ),
            const SizedBox(height: 14),
            if (monetization.iapStatusMessage != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  monetization.iapStatusMessage!,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    title: 'Käufe wiederherstellen',
                    icon: Icons.refresh_rounded,
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
                  child: _SheetButton(
                    title: monetization.isPremium
                        ? 'Premium aktiv'
                        : 'Premium kaufen',
                    icon: Icons.workspace_premium_rounded,
                    primary: true,
                    onTap: monetization.isPremium ||
                            monetization.isPurchaseBusy ||
                            !monetization.canAttemptPurchase
                        ? null
                        : () async {
                            final ok = await monetization.buyPremium();
                            if (!context.mounted) return;
                            if (ok) Navigator.pop(context);
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
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

class _SheetButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const _SheetButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: primary
          ? Colors.white.withValues(alpha: enabled ? 0.14 : 0.08)
          : Colors.white.withValues(alpha: enabled ? 0.08 : 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!enabled)
                const SizedBox.shrink()
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
