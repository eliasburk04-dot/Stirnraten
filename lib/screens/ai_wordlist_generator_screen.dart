import 'package:flutter/material.dart';

import '../services/ai_wordlist_service.dart';
import '../services/supabase_wordlist_repository.dart';
import '../theme/stirnraten_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _vm = AIWordlistViewModel(
      aiService: widget.aiService,
      repository: widget.repository,
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('KI-Wörterliste'),
            actions: [
              TextButton(
                onPressed: _vm.canSave ? _save : null,
                child: const Text('Speichern'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildForm(),
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
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _vm.state == AIWordlistUiState.loading
                          ? null
                          : () => _vm.regenerate(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Neu generieren'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _vm.canGenerate
                          ? () {
                              _vm.generate();
                            }
                          : null,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Generieren'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thema'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _vm.topic,
              decoration: const InputDecoration(hintText: 'z.B. Fußball'),
              onChanged: (value) => _vm.topic = value,
            ),
            const SizedBox(height: 12),
            const Text('Titel (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _vm.title,
              decoration:
                  const InputDecoration(hintText: 'z.B. Bundesliga Easy'),
              onChanged: (value) => _vm.title = value,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _vm.language,
                    decoration: const InputDecoration(labelText: 'Sprache'),
                    items: const [
                      DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _vm.language = value;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<AIWordlistDifficulty>(
                    initialValue: _vm.difficulty,
                    decoration:
                        const InputDecoration(labelText: 'Schwierigkeit'),
                    items: const [
                      DropdownMenuItem(
                        value: AIWordlistDifficulty.easy,
                        child: Text('Easy'),
                      ),
                      DropdownMenuItem(
                        value: AIWordlistDifficulty.medium,
                        child: Text('Medium'),
                      ),
                      DropdownMenuItem(
                        value: AIWordlistDifficulty.hard,
                        child: Text('Hard'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _vm.difficulty = value;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Anzahl Begriffe'),
                const Spacer(),
                IconButton(
                  onPressed: _vm.count > 5
                      ? () => setState(() => _vm.count = _vm.count - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${_vm.count}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: _vm.count < 100
                      ? () => setState(() => _vm.count = _vm.count + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _vm.tagsRaw,
              decoration: const InputDecoration(
                labelText: 'Stil-Tags (optional)',
                hintText: 'Bundesliga, EM, Kinderfreundlich',
              ),
              onChanged: (value) => _vm.tagsRaw = value,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _vm.includeHints,
              title: const Text('Kurze Hinweise einbeziehen'),
              subtitle: const Text('Standard: aus'),
              onChanged: (value) => setState(() => _vm.includeHints = value),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vorschau (${_vm.previewItems.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...List.generate(_vm.previewItems.length, (index) {
              final term = _vm.previewItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: term,
                        onChanged: (value) => _vm.updateItem(index, value),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _vm.removeItemAt(index)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: StirnratenColors.categoryPrimary,
              ),
              onPressed: _vm.canSave ? _save : null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('In Supabase speichern'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: value),
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
    return Card(
      color: const Color(0xFFFFF1F2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFB91C1C),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
