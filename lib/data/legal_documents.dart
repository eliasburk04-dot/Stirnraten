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
        stand: '10.02.2026',
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
              'Viele Daten werden lokal auf deinem Gerät gespeichert '
                  '(offline-first). Zusätzlich werden für KI-Listen und '
                  'Cloud-Sync serverseitige Dienste genutzt.',
            ],
            bullets: <String>[
              'Lokale Spiel- und Einstellungsdaten (App-Speicher)',
              'Manuell erstellte Wortlisten (lokal)',
              'Sensorwerte (z. B. Beschleunigungssensor) für die '
                  'Spielsteuerung',
              'Anonyme Supabase Nutzer-ID für KI/Cloud-Funktionen',
            ],
          ),
          LegalSection(
            title: '4. Supabase (Cloud, KI, Quota)',
            paragraphs: <String>[
              'Für KI-Wortlisten und Cloud-Speicherung nutzen wir Supabase '
                  '(Datenbank, Authentifizierung, Edge Functions).',
            ],
            bullets: <String>[
              'KI-Wortlisten: Titel, Sprache, Begriffe',
              'KI-Nutzung pro Tag (Quota, Europe/Berlin Datumsschlüssel)',
              'Premium-Status als serverseitiges Flag zur Limit-Durchsetzung',
            ],
          ),
          LegalSection(
            title: '5. In-App-Käufe (Premium)',
            paragraphs: <String>[
              'Premium wird über Apple App Store bzw. Google Play verkauft. '
                  'Zahlungsdaten werden durch den jeweiligen Store verarbeitet. '
                  'Zur serverseitigen Prüfung des Premium-Status können '
                  'Transaktionsdaten (z. B. Kaufbeleg/Purchase Token) '
                  'an unseren Backend-Dienst (Supabase) übertragen werden.',
            ],
          ),
          LegalSection(
            title: '6. KI-Wortlisten (Groq, serverseitig)',
            paragraphs: <String>[
              'Die KI-Generierung wird serverseitig über eine Supabase Edge '
                  'Function ausgeführt, die eine KI-API (Groq) aufruft. '
                  'Übertragen werden typischerweise Thema/Sprache/Schwierigkeit '
                  'und die gewünschte Anzahl. Bitte keine sensiblen oder '
                  'personenbezogenen Daten als Prompt eingeben.',
            ],
          ),
          LegalSection(
            title: '7. Zwecke und Rechtsgrundlagen',
            bullets: <String>[
              'Bereitstellung der App-Funktionen '
                  '(Art. 6 Abs. 1 lit. b DSGVO)',
              'KI- und Cloud-Funktionen '
                  '(Art. 6 Abs. 1 lit. b DSGVO)',
              'Technische Stabilität und Sicherheit '
                  '(Art. 6 Abs. 1 lit. f DSGVO)',
              'Missbrauchsschutz/Quota '
                  '(Art. 6 Abs. 1 lit. f DSGVO)',
              'Erfüllung gesetzlicher Pflichten '
                  '(Art. 6 Abs. 1 lit. c DSGVO)',
            ],
          ),
          LegalSection(
            title: '8. Empfänger und Dienstleister',
            bullets: <String>[
              'Supabase (Backend: Datenbank, Auth, Edge Functions)',
              'Groq (KI-API, serverseitig)',
              'Apple App Store / Google Play (Kaufabwicklung, Restore)',
            ],
          ),
          LegalSection(
            title: '9. Speicherdauer',
            paragraphs: <String>[
              'Lokal gespeicherte Daten verbleiben bis zur Löschung in der '
                  'App oder Deinstallation.',
              'Cloud-Daten (z. B. KI-Listen/Quota) werden gespeichert, solange '
                  'sie für die App-Funktionen erforderlich sind oder bis zur '
                  'Löschung.',
            ],
          ),
          LegalSection(
            title: '10. Betroffenenrechte',
            bullets: <String>[
              'Auskunft, Berichtigung, Löschung',
              'Einschränkung der Verarbeitung',
              'Datenübertragbarkeit',
              'Widerspruch gegen bestimmte Verarbeitungen',
              'Beschwerde bei einer Datenschutzaufsichtsbehörde',
            ],
          ),
          LegalSection(
            title: '11. Änderungen',
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
        stand: '10.02.2026',
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
