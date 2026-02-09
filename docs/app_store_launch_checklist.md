# iOS App Store Launch Checklist

## 1) Technical preflight (local)

Run:

```bash
bash scripts/ios_app_store_preflight.sh
```

This validates:
- `flutter analyze`
- `flutter test`
- `flutter build ios --release --no-codesign`
- `Info.plist` contains:
  - `UIApplicationSceneManifest`
  - `NSMotionUsageDescription`
  - `ITSAppUsesNonExemptEncryption`

## 2) Xcode signing

- Use a current Xcode version that ships with the iOS 26 SDK (required for App Store submissions starting April 2026).
- Open `ios/Runner.xcworkspace` in Xcode.
- Set Apple Team.
- Set unique bundle identifier.
- Enable automatic signing for `Runner` (Release).
- Archive once in Xcode (`Product -> Archive`) and verify no signing warnings remain.

## 3) App Store Connect app record

- Create app entry with matching bundle identifier.
- Set app name/subtitle/category.
- Set pricing/availability.
- Upload archive from Xcode Organizer.

## 4) Metadata and legal

- App description, keywords, support URL, marketing URL.
- Privacy Policy URL and legal pages.
- Age rating questionnaire.
- Export compliance (encryption).

## 5) Privacy and tracking declarations

- Complete App Privacy questionnaire (data collection) in App Store Connect.
- If no tracking is used, keep ATT disabled and answer accordingly.

## 6) Monetarisierung (kostenloses Launch-Modell)

- Keine In-App-Käufe konfigurieren.
- In App Store Connect keine IAP-Produkte anhängen oder einreichen.
- Preisstufe der App auf kostenlos setzen.
- Metadata/Description ohne Hinweise auf Paywall oder Abo halten.

## 7) Assets

- App icon set complete (including 1024x1024).
- iPhone screenshots for required sizes.
- Optional preview videos.

## 8) Final QA (device)

- Fresh install test on real iPhone.
- Motion sensor flow: calibrate -> correct/pass -> no repeat trigger loop.
- Audio test with silent mode on/off.
- Offline test.
- Background/foreground lifecycle test during running game.

## 9) Heute-Abend-Plan (TestFlight, ohne Kabel/gleiches Netzwerk)

Heute ist **Samstag, 7. Februar 2026**.  
Wenn ihr heute Abend spielen wollt, ist der schnellste Weg:

### A) Schnellster Weg heute: interne TestFlight-Tester

1. App Store Connect öffnen und prüfen:
   - App-Eintrag existiert.
   - Bundle-ID stimmt mit Xcode-Projekt überein.
2. In Xcode `ios/Runner.xcworkspace` öffnen:
   - Team + Signing für `Runner` (Release) korrekt.
   - `Product -> Archive`.
3. Nach dem Archive:
   - `Distribute App -> App Store Connect -> Upload`.
4. Warten bis der Build in App Store Connect/TestFlight verarbeitet ist (oft 10-30 Minuten).
5. Freunde als **interne Tester** hinzufügen:
   - App Store Connect -> `Users and Access` -> Benutzer einladen.
   - Danach in `TestFlight` einer internen Gruppe zuweisen.
6. Freunde installieren die App `TestFlight` aus dem App Store und akzeptieren die Einladung.

Hinweis:
- Interne Tester funktionieren ohne Beta-App-Review.
- Builds laufen nach 90 Tagen ab.

### B) Externe Tester (nur falls nötig)

- Externe Tester benötigen Beta-App-Review.
- Das kann schnell gehen, ist aber zeitlich nicht garantiert und daher für „heute Abend“ riskanter.

### C) Minimal-Check vor dem Verteilen

1. Spiel startet und Kategorien lassen sich auswählen.
2. Tilt/Neigung triggert korrekt (richtig/passen).
3. Keine gelb-schwarzen Overflow-Balken mehr.
4. Audio + haptisches Feedback funktionieren.

### D) Wenn der Build nicht erscheint

1. In App Store Connect unter `Agreements, Tax and Banking` prüfen, ob etwas offen ist.
2. In TestFlight warten, bis der Status nicht mehr „Processing“ ist.
3. Sicherstellen, dass der Upload mit derselben Bundle-ID erfolgt ist.
