# Premium IAP Setup (iOS App Store)

Diese App nutzt einen **non-consumable** Premium-Kauf per `in_app_purchase`.

## 1) Product in App Store Connect anlegen

1. In App Store Connect: `My Apps` -> deine App -> `In-App Purchases`.
2. Typ: `Non-Consumable`.
3. Product ID anlegen (muss exakt zur App-Konfiguration passen).
4. Preisstufe setzen.
5. Metadaten + Screenshot fuer Review hinterlegen.

Offizielle Quelle:  
https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-up-in-app-purchases

## 2) Product IDs in der App konfigurieren

Die App liest IDs aus:

- `IAP_PRODUCT_IDS` (comma-separated)
- Fallback: `stirnraten_premium_499`

Beispiel lokal:

```bash
flutter run \
  --dart-define=IAP_PRODUCT_IDS=com.stirnraten.premium.lifetime
```

Beispiel Build:

```bash
flutter build ipa \
  --dart-define=IAP_PRODUCT_IDS=com.stirnraten.premium.lifetime
```

## 3) Server-Verifikation (empfohlen fuer Release)

Apple empfiehlt Server-seitige Verifikation von In-App-Kaeufen.  
Die App kann optional einen Verify-Endpoint aufrufen:

- `IAP_VERIFICATION_ENDPOINT=https://your-api.example.com/iap/verify`

Payload:

```json
{
  "productId": "com.stirnraten.premium.lifetime",
  "purchaseId": "...",
  "transactionDate": "...",
  "source": "app_store",
  "serverVerificationData": "...",
  "localVerificationData": "..."
}
```

Erwartete API-Antwort:

```json
{
  "valid": true
}
```

Offizielle Quellen:
- Flutter Plugin Doku (`in_app_purchase`): https://pub.dev/packages/in_app_purchase
- Apple Receipt Validation: https://developer.apple.com/documentation/storekit/validating-receipts-with-the-app-store

## 4) Testen auf iPhone

Moeglichkeiten:

1. Sandbox Tester in App Store Connect verwenden.
2. Oder StoreKit-Test in Xcode mit `.storekit` Konfiguration.

Offizielle Quellen:
- Sandbox overview: https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox
- StoreKit testing in Xcode: https://developer.apple.com/documentation/xcode/testing-in-app-purchases-with-storekit-transaction-manager-in-code

## 5) Verhalten in dieser App

- Premium-Logik bleibt unveraendert (gleiche Freischaltungen).
- Falls Store/Produkt nicht verfuegbar ist, zeigt die Paywall jetzt klare Diagnosen:
  - Store nicht verfuegbar
  - Product ID nicht gefunden
  - Retry (`Store erneut pruefen`)
- In Debug-Builds gibt es zusaetzlich `Debug: Premium freischalten` zum Testen der Premium-UI ohne Store.
