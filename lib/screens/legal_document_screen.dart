import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/legal_documents.dart';

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType documentType;

  const LegalDocumentScreen({
    super.key,
    required this.documentType,
  });

  @override
  Widget build(BuildContext context) {
    final document = legalDocumentForType(documentType);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          document.title,
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFF111827),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _LegalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stand: ${document.stand}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final paragraph in document.intro) ...[
                    SelectableText(
                      paragraph,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final section in document.sections) ...[
              _LegalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final paragraph in section.paragraphs) ...[
                      SelectableText(
                        paragraph,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (final bullet in section.bullets) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              bullet,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                height: 1.45,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _LegalCard(
              child: SelectableText(
                document.footerHinweis,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFDE68A),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final Widget child;

  const _LegalCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}
