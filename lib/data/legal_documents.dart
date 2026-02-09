enum LegalDocumentType {
  datenschutzerklaerung,
  impressum,
}

class LegalSection {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  const LegalSection({
    required this.title,
    this.paragraphs = const <String>[],
    this.bullets = const <String>[],
  });
}

class LegalDocument {
  final String title;
  final String stand;
  final List<String> intro;
  final List<LegalSection> sections;
  final String footerHinweis;

  const LegalDocument({
    required this.title,
    required this.stand,
    required this.intro,
    required this.sections,
    required this.footerHinweis,
  });
}

LegalDocument legalDocumentForType(LegalDocumentType type) {
  switch (type) {
    case LegalDocumentType.datenschutzerklaerung:
      return const LegalDocument(
        title: 'Datenschutzerklärung',
        stand: '09.02.2026',
        intro: <String>[
          'Diese Datenschutzerklärung informiert über die Verarbeitung '
              'personenbezogener Daten bei der Nutzung der App „Stirnraten“.',
        ],
        sections: <LegalSection>[
          LegalSection(
            title: '1. Verantwortlicher',
            paragraphs: <String>[
              'Elias Burk',
              'Friedrich-Naumann Straße 11',
              '71636 Ludwigsburg, Deutschland',
              'E-Mail: eliasburk04@gmail.com',
            ],
          ),
          LegalSection(
            title: '2. Datenschutzkontakt',
            paragraphs: <String>[
              'Anfragen zum Datenschutz bitte an:',
              'eliasburk04@gmail.com',
              'Datenschutzbeauftragter: nicht benannt',
            ],
          ),
          LegalSection(
            title: '3. Verarbeitete Daten in der App',
            paragraphs: <String>[
              'Die App ist auf lokale Nutzung ausgelegt. Spielstände und '
                  'Einstellungen werden lokal auf dem Gerät gespeichert.',
            ],
            bullets: <String>[
              'Lokale Spiel- und Einstellungsdaten (App-Speicher)',
              'Sensorwerte (z. B. Beschleunigungssensor) für die '
                  'Spielsteuerung',
              'Keine Registrierung, kein eigenes Nutzerkonto in der App',
            ],
          ),
          LegalSection(
            title: '4. Monetarisierung',
            paragraphs: <String>[
              'Die App wird aktuell vollständig kostenlos bereitgestellt.',
              'Es werden keine In-App-Käufe oder bezahlten Freischaltungen '
                  'angeboten.',
            ],
          ),
          LegalSection(
            title: '5. Zwecke und Rechtsgrundlagen',
            bullets: <String>[
              'Bereitstellung der App-Funktionen '
                  '(Art. 6 Abs. 1 lit. b DSGVO)',
              'Technische Stabilität und Sicherheit '
                  '(Art. 6 Abs. 1 lit. f DSGVO)',
              'Erfüllung gesetzlicher Pflichten '
                  '(Art. 6 Abs. 1 lit. c DSGVO)',
            ],
          ),
          LegalSection(
            title: '6. Empfänger und Dienstleister',
            paragraphs: <String>[
              'Für den App-Vertrieb werden Plattformdienste von Apple bzw. '
                  'Google genutzt.',
              'Aktuell kein eigener Backend-Service für die App im produktiven '
                  'Betrieb.',
              'Vercel wird für die Portfolio-Website genutzt, nicht für die '
                  'Spiel-Funktionen innerhalb der mobilen App.',
            ],
          ),
          LegalSection(
            title: '7. Speicherdauer',
            paragraphs: <String>[
              'Lokal gespeicherte Daten verbleiben bis zur Löschung in der '
                  'App oder Deinstallation.',
            ],
          ),
          LegalSection(
            title: '8. Betroffenenrechte',
            bullets: <String>[
              'Auskunft, Berichtigung, Löschung',
              'Einschränkung der Verarbeitung',
              'Datenübertragbarkeit',
              'Widerspruch gegen bestimmte Verarbeitungen',
              'Beschwerde bei einer Datenschutzaufsichtsbehörde',
            ],
          ),
          LegalSection(
            title: '9. Änderungen',
            paragraphs: <String>[
              'Diese Datenschutzerklärung kann angepasst werden, wenn sich '
                  'Funktionen oder rechtliche Anforderungen ändern.',
            ],
          ),
        ],
        footerHinweis: 'Hinweis: Diese Vorlage ist kein Ersatz für eine '
            'individuelle Rechtsberatung.',
      );
    case LegalDocumentType.impressum:
      return const LegalDocument(
        title: 'Impressum',
        stand: '09.02.2026',
        intro: <String>[
          'Angaben gemäß § 5 DDG.',
        ],
        sections: <LegalSection>[
          LegalSection(
            title: '1. Anbieter',
            paragraphs: <String>[
              'Elias Burk',
              'Friedrich-Naumann Straße 11',
              '71636 Ludwigsburg, Deutschland',
            ],
          ),
          LegalSection(
            title: '2. Kontakt',
            paragraphs: <String>[
              'E-Mail: eliasburk04@gmail.com',
              'Telefon: nicht angegeben',
            ],
          ),
          LegalSection(
            title: '3. Vertretungsberechtigt (bei juristischer Person)',
            paragraphs: <String>[
              'Nicht zutreffend (natürliche Person, kein Unternehmen).',
            ],
          ),
          LegalSection(
            title: '4. Registereintrag (falls vorhanden)',
            paragraphs: <String>[
              'Nicht vorhanden.',
            ],
          ),
          LegalSection(
            title: '5. Umsatzsteuer-ID (falls vorhanden)',
            paragraphs: <String>[
              'Nicht vorhanden.',
            ],
          ),
          LegalSection(
            title: '6. Inhaltlich verantwortlich',
            paragraphs: <String>[
              'Elias Burk',
              'Friedrich-Naumann Straße 11, 71636 Ludwigsburg, Deutschland',
            ],
          ),
          LegalSection(
            title: '7. Verbraucherstreitbeilegung',
            paragraphs: <String>[
              'Hinweis gemäß § 36 VSBG: Es besteht keine Bereitschaft und '
                  'keine Verpflichtung zur Teilnahme an '
                  'Streitbeilegungsverfahren vor einer '
                  'Verbraucherschlichtungsstelle.',
            ],
          ),
        ],
        footerHinweis: 'Hinweis: Diese Vorlage ist kein Ersatz für eine '
            'individuelle Rechtsberatung.',
      );
  }
}
