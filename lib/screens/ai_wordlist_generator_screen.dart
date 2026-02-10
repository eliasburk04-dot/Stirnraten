import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../monetization/ai_usage_snapshot.dart';
import '../monetization/monetization_controller.dart';
import '../monetization/premium_paywall.dart';
import '../services/ai_wordlist_service.dart';
import '../services/supabase_wordlist_repository.dart';
import '../theme/stirnraten_colors.dart';
import '../utils/effects_quality.dart';
import '../utils/word_token_count.dart';
import '../widgets/glass_widgets.dart';
import '../viewmodels/ai_wordlist_view_model.dart';

class AIWordlistGeneratorScreen extends StatefulWidget {
  final AIWordlistService aiService;
  final WordlistRepository repository;

  const AIWordlistGeneratorScreen({
    super.key,
    required this.aiService,
    required this.repository,
  });

  @override
  State<AIWordlistGeneratorScreen> createState() =>
      _AIWordlistGeneratorScreenState();
}

class _AIWordlistGeneratorScreenState extends State<AIWordlistGeneratorScreen> {
  late final AIWordlistViewModel _vm;
  late final TextEditingController _topicController;
  late final TextEditingController _titleController;
  final List<TextEditingController> _previewControllers =
      <TextEditingController>[];
  String? _lastAppliedUsageToken;
  String? _lastQuotaPaywallToken;
  String? _lastTrimNoticeToken;

  @override
  void initState() {
    super.initState();
    _vm = AIWordlistViewModel(
      aiService: widget.aiService,
      repository: widget.repository,
    );
    _topicController = TextEditingController(text: _vm.topic)
      ..addListener(() {
        final next = _topicController.text;
        if (_vm.topic == next) return;
        setState(() => _vm.topic = next);
      });
    _titleController = TextEditingController(text: _vm.title)
      ..addListener(() {
        final next = _titleController.text;
        if (_vm.title == next) return;
        setState(() => _vm.title = next);
      });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _titleController.dispose();
    for (final controller in _previewControllers) {
      controller.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  void _syncPreviewControllers() {
    final items = _vm.previewItems;
    if (_previewControllers.length == items.length) {
      for (var i = 0; i < items.length; i++) {
        final text = items[i];
        final controller = _previewControllers[i];
        if (controller.text != text) {
          controller.text = text;
        }
      }
      return;
    }

    for (final controller in _previewControllers) {
      controller.dispose();
    }
    _previewControllers
      ..clear()
      ..addAll(items.map((term) => TextEditingController(text: term)));
  }

  Future<void> _save() async {
    final monetization = context.read<MonetizationController>();
    final maxAllowed = monetization.maxWordsPerList;
    final tokenCount = WordTokenCount.count(_vm.previewItems);
    if (tokenCount > maxAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Maximal $maxAllowed Wörter pro Liste (aktuell: $tokenCount).'),
        ),
      );
      await showPremiumPaywall(
        context,
        trigger: PaywallTrigger.wordLimit,
        message: 'Maximal $maxAllowed Wörter pro Liste.',
      );
      return;
    }
    final saved = await _vm.save();
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, saved);
      return;
    }
    if (_vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_vm.errorMessage!)),
      );
    }
  }

  Future<void> _generate() async {
    final monetization = context.read<MonetizationController>();
    if (!monetization.canStartAiGenerationLocally() && !monetization.isPremium) {
      await showPremiumPaywall(
        context,
        trigger: PaywallTrigger.aiQuota,
        message: 'Heute sind 3 KI-Generierungen frei. Premium = unbegrenzt.',
      );
      return;
    }
    await _vm.generate();
  }

  void _applyUsageIfPresent(AiUsageSnapshot? usage) {
    if (usage == null) return;
    final token = '${usage.dateKey}:${usage.used}:${usage.limit}';
    if (_lastAppliedUsageToken == token) return;
    _lastAppliedUsageToken = token;
    unawaited(context.read<MonetizationController>().applyServerAiUsage(usage));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final maxAllowed = context.watch<MonetizationController>().maxWordsPerList;
        _applyUsageIfPresent(_vm.lastUsage);
        if (_vm.lastErrorWasQuotaExceeded) {
          final usage = _vm.lastUsage;
          final token =
              '${usage?.dateKey ?? 'na'}:${usage?.used ?? -1}:${_vm.errorMessage ?? ''}';
          if (_lastQuotaPaywallToken != token) {
            _lastQuotaPaywallToken = token;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showPremiumPaywall(
                context,
                trigger: PaywallTrigger.aiQuota,
                message: _vm.errorMessage ??
                    'Heute sind 3 KI-Generierungen frei. Premium = unbegrenzt.',
              );
            });
          }
        }
        final tokenCount = WordTokenCount.count(_vm.previewItems);
        if (tokenCount > maxAllowed) {
          final token = '$tokenCount:$maxAllowed';
          if (_lastTrimNoticeToken != token) {
            _lastTrimNoticeToken = token;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Auf $maxAllowed Wörter gekürzt.'),
                ),
              );
              _vm.enforceMaxWordTokens(maxAllowed);
            });
          }
        }
        _syncPreviewControllers();
        return Scaffold(
          body: Stack(
            children: [
              const _CategoryBackground(),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                      child: Row(
                        children: [
                          _HeaderIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'KI-Wörterliste',
                              style: GoogleFonts.fredoka(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: StirnratenColors.categoryText,
                              ),
                            ),
                          ),
                          _PrimaryPillButton(
                            label: 'Speichern',
                            icon: Icons.check_rounded,
                            onTap: _vm.canSave ? _save : null,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            const _SectionLabel('Thema'),
                            const SizedBox(height: 6),
                            _GlassInputField(
                              controller: _topicController,
                              hint: 'z.B. Fußball',
                              maxLines: 1,
                            ),
                            const SizedBox(height: 14),
                            const _SectionLabel('Titel (optional)'),
                            const SizedBox(height: 6),
                            _GlassInputField(
                              controller: _titleController,
                              hint: 'z.B. Bundesliga Easy',
                              maxLines: 1,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _GlassSegmentedControl<
                                      AIWordlistLanguage>(
                                    label: 'Sprache',
                                    value: _vm.language == 'de'
                                        ? AIWordlistLanguage.de
                                        : AIWordlistLanguage.en,
                                    items: const [
                                      _SegmentItem(
                                        value: AIWordlistLanguage.de,
                                        label: 'Deutsch',
                                      ),
                                      _SegmentItem(
                                        value: AIWordlistLanguage.en,
                                        label: 'Englisch',
                                      ),
                                    ],
                                    onChanged: (value) => setState(() {
                                      _vm.language =
                                          value == AIWordlistLanguage.de
                                              ? 'de'
                                              : 'en';
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _GlassSegmentedControl<
                                      AIWordlistDifficulty>(
                                    label: 'Schwierigkeit',
                                    value: _vm.difficulty,
                                    items: const [
                                      _SegmentItem(
                                        value: AIWordlistDifficulty.easy,
                                        label: 'Leicht',
                                      ),
                                      _SegmentItem(
                                        value: AIWordlistDifficulty.medium,
                                        label: 'Mittel',
                                      ),
                                      _SegmentItem(
                                        value: AIWordlistDifficulty.hard,
                                        label: 'Schwer',
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _vm.difficulty = value),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const _SectionLabel('Anzahl Begriffe'),
                                const Spacer(),
                                _CountButton(
                                  icon: Icons.remove_rounded,
                                  onTap: _vm.count > 5
                                      ? () => setState(() => _vm.count--)
                                      : null,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${_vm.count}',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: StirnratenColors.categoryText,
                                    ),
                                  ),
                                ),
                                _CountButton(
                                  icon: Icons.add_rounded,
                                  onTap: _vm.count < 100
                                      ? () => setState(() => _vm.count++)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_vm.state == AIWordlistUiState.loading)
                              _LoadingCard(
                                progress: _vm.progress,
                                label: _vm.progressLabel,
                              ),
                            if (_vm.errorMessage != null) ...[
                              const SizedBox(height: 10),
                              _ErrorCard(message: _vm.errorMessage!),
                            ],
                            if (_vm.previewItems.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildPreview(),
                            ],
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SecondaryPillButton(
                              label: 'Abbrechen',
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PrimaryPillButton(
                              label: _vm.previewItems.isNotEmpty
                                  ? 'Speichern'
                                  : 'Generieren',
                              icon: _vm.previewItems.isNotEmpty
                                  ? Icons.check_rounded
                                  : Icons.auto_awesome_rounded,
                              onTap: _vm.previewItems.isNotEmpty
                                  ? (_vm.canSave ? _save : null)
                                  : (_vm.canGenerate
                                      ? _generate
                                      : null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;

    return GlassBackdrop(
      blurSigma: blurSigma,
      enableBlur: effects.allowBlur,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StirnratenColors.categoryGlass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StirnratenColors.categoryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Vorschau (${_vm.previewItems.length})',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StirnratenColors.categoryText,
                  ),
                ),
                const Spacer(),
                _SmallPillButton(
                  label: 'Neu',
                  icon: Icons.refresh_rounded,
                  onTap: _vm.state == AIWordlistUiState.loading
                      ? null
                      : () => _vm.regenerate(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_vm.previewItems.length, (index) {
              final controller = _previewControllers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _GlassInputField(
                        controller: controller,
                        hint: 'Begriff',
                        maxLines: 1,
                        onChanged: (value) => _vm.updateItem(index, value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconCircleButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: () => setState(() => _vm.removeItemAt(index)),
                    ),
                  ],
                ),
              );
            }),
            if (_vm.previewItems.length < 5)
              Text(
                'Mindestens 5 Begriffe erforderlich.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double progress;
  final String label;

  const _LoadingCard({
    required this.progress,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final value = progress <= 0 ? null : progress.clamp(0.0, 1.0).toDouble();
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;
    return GlassBackdrop(
      blurSigma: blurSigma,
      enableBlur: effects.allowBlur,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StirnratenColors.categoryGlass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StirnratenColors.categoryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: StirnratenColors.categoryMuted,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  StirnratenColors.categoryPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;
    return GlassBackdrop(
      blurSigma: blurSigma,
      enableBlur: effects.allowBlur,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          message,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFEF4444),
          ),
        ),
      ),
    );
  }
}

enum AIWordlistLanguage { de, en }

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: StirnratenColors.categoryMuted,
      ),
    );
  }
}

class _SegmentItem<T> {
  final T value;
  final String label;

  const _SegmentItem({required this.value, required this.label});
}

class _GlassSegmentedControl<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<_SegmentItem<T>> items;
  final ValueChanged<T> onChanged;

  const _GlassSegmentedControl({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 6),
        GlassBackdrop(
          blurSigma: blurSigma,
          enableBlur: effects.allowBlur,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: StirnratenColors.categoryGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: StirnratenColors.categoryBorder),
            ),
            child: Row(
              children: [
                for (final item in items) ...[
                  Expanded(
                    child: _SegmentButton(
                      label: item.label,
                      selected: item.value == value,
                      onTap: () => onChanged(item.value),
                    ),
                  ),
                  if (item != items.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.55),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: StirnratenColors.categoryText,
          ),
        ),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CountButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, color: StirnratenColors.categoryText, size: 18),
        ),
      ),
    );
  }
}

class _SmallPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SmallPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: StirnratenColors.categoryText),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
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
        child: Icon(icon, color: StirnratenColors.categoryText, size: 22),
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
  final VoidCallback onTap;

  const _SecondaryPillButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: StirnratenColors.categoryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, color: StirnratenColors.categoryText, size: 20),
      ),
    );
  }
}

class _GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  const _GlassInputField({
    required this.controller,
    required this.hint,
    this.maxLines,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurSigma =
        effects.allowBlur ? effects.blur(high: 6, medium: 4, low: 0) : 0.0;
    return GlassBackdrop(
      blurSigma: blurSigma,
      enableBlur: effects.allowBlur,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: StirnratenColors.categoryGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: StirnratenColors.categoryBorder),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: StirnratenColors.categoryText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: StirnratenColors.categoryMuted.withValues(alpha: 0.6),
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryBackground extends StatelessWidget {
  const _CategoryBackground();

  @override
  Widget build(BuildContext context) {
    final effects = EffectsConfig.of(context);
    final blurRadius = effects.shadowBlur(high: 95, medium: 70, low: 45);
    final spreadRadius = effects.shadowBlur(high: 12, medium: 8, low: 5);
    return RepaintBoundary(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              StirnratenColors.categoryBackgroundTop,
              StirnratenColors.categoryBackgroundMid,
              StirnratenColors.categoryBackgroundBottom,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -60,
              child: _GlowOrb(
                color: const Color(0xFFFFF1A6).withValues(alpha: 0.35),
                size: 280,
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ),
            Positioned(
              bottom: -140,
              left: -80,
              child: _GlowOrb(
                color: const Color(0xFFFF9FCE).withValues(alpha: 0.28),
                size: 320,
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ),
            Positioned(
              top: 240,
              left: -60,
              child: _GlowOrb(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                size: 220,
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double blurRadius;
  final double spreadRadius;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.blurRadius,
    required this.spreadRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
    );
  }
}
