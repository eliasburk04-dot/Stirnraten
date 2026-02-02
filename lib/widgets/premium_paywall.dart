import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/purchase_service.dart';
import '../theme/stirnraten_colors.dart';

class PremiumPaywallSheet extends StatelessWidget {
  const PremiumPaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseService>();
    final isPremium = purchase.isPremium;
    final storeAvailable = purchase.storeAvailable;
    final isBusy = purchase.isPurchasePending || purchase.isLoading;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF10121B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, -10),
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
                  'Premium freischalten',
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: StirnratenColors.categoryText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Alle Kategorien, eigene Listen und alle Modi.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StirnratenColors.categoryMuted,
              ),
            ),
            const SizedBox(height: 16),
            const _FeatureRow(text: 'Alle Kategorien freischalten'),
            const _FeatureRow(text: 'Eigene Listen erstellen und spielen'),
            const _FeatureRow(text: 'Sudden, Hardcore und Trinkspiel'),
            const SizedBox(height: 16),
            if (!storeAvailable && !isPremium)
              Text(
                'Store aktuell nicht verfuegbar.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade200,
                ),
              ),
            if (purchase.lastError != null && !isPremium) ...[
              const SizedBox(height: 8),
              Text(
                purchase.lastError!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (isPremium) ...[
              Text(
                'Premium ist aktiv.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.greenAccent.shade100,
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryButton(
                label: 'Schliessen',
                onPressed: () => Navigator.pop(context),
              ),
            ] else ...[
              _PrimaryButton(
                label: 'Jetzt freischalten • ${purchase.priceLabel}',
                onPressed: storeAvailable && !isBusy
                    ? purchase.buyPremium
                    : null,
                isBusy: isBusy,
              ),
              const SizedBox(height: 8),
              _GhostButton(
                label: 'Kauf wiederherstellen',
                onPressed: storeAvailable && !isBusy
                    ? purchase.restorePurchases
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;

  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StirnratenColors.categoryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: StirnratenColors.categoryPrimary,
          foregroundColor: StirnratenColors.categoryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GhostButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: StirnratenColors.categoryText,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
