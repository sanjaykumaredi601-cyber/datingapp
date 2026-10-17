# NextGen IT Global - Multi-Environment Firebase Configuration Guide

## 1. Executive Summary & Architecture Strategy
To guarantee data privacy, compliance (DPDP, PIPEDA, GDPR), and zero bleed between testing and live member data, **NextGen IT Global** mandates strict separation between **Staging** and **Production** environments for the Aura dating application.

```
                      ┌──────────────────────────────────────────┐
                      │          NextGen IT Global CI/CD         │
                      └────────────────────┬─────────────────────┘
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    ▼                                             ▼
       ┌────────────────────────┐                    ┌────────────────────────┐
       │   Staging Environment  │                    │ Production Environment │
       │ (aura-dating-staging)  │                    │   (aura-dating-prod)   │
       ├────────────────────────┤                    ├────────────────────────┤
       │ • QA & Regression      │                    │ • Live Members         │
       │ • Test SMS & Mock Auth │                    │ • Production Firestore │
       │ • Sandbox Cloud billing│                    │ • Live Razorpay/In-App │
       └────────────────────────┘                    └────────────────────────┘
```

---

## 2. Directory Structure for Flavors

### Android Product Flavors
Place platform-specific configuration files in distinct source sets within `android/app/src/`:

```
aura_app/
├── android/
│   └── app/
│       ├── build.gradle
│       └── src/
│           ├── main/
│           │   └── AndroidManifest.xml
│           ├── staging/
│           │   └── google-services.json       # Injected during build (Git-ignored)
│           └── production/
│               └── google-services.json       # Injected during build (Git-ignored)
```

In `android/app/build.gradle`:
```groovy
android {
    ...
    flavorDimensions "environment"

    productFlavors {
        staging {
            dimension "environment"
            applicationIdSuffix ".staging"
            resValue "string", "app_name", "Aura Staging"
        }
        production {
            dimension "environment"
            resValue "string", "app_name", "Aura"
        }
    }
}
```

### iOS Schemes & Run Script
Store environment `.plist` files under `ios/config/`:
```
aura_app/
└── ios/
    └── config/
        ├── staging/
        │   └── GoogleService-Info.plist       # Injected during build (Git-ignored)
        └── production/
            └── GoogleService-Info.plist       # Injected during build (Git-ignored)
```

Add an Xcode **Run Script Phase** before *Compile Sources*:
```bash
# Setup Environment Plist
if [ "$CONFIGURATION" == "Debug-staging" ] || [ "$CONFIGURATION" == "Release-staging" ]; then
    cp -r "$PROJECT_DIR/config/staging/GoogleService-Info.plist" "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/GoogleService-Info.plist"
elif [ "$CONFIGURATION" == "Debug-production" ] || [ "$CONFIGURATION" == "Release-production" ]; then
    cp -r "$PROJECT_DIR/config/production/GoogleService-Info.plist" "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/GoogleService-Info.plist"
fi
```

---

## 3. Git Security & Ignore Configuration
Raw credentials, service account keys, and `google-services.json` must **never** be committed to public or shared version control.

Add the following to `.gitignore`:
```gitignore
# Firebase & GCP Environment Configuration
android/app/google-services.json
android/app/src/staging/google-services.json
android/app/src/production/google-services.json
ios/Runner/GoogleService-Info.plist
ios/config/staging/GoogleService-Info.plist
ios/config/production/GoogleService-Info.plist

# Flutter generated environment options
lib/firebase_options_staging.dart
lib/firebase_options_production.dart
*.env
*.env.*
```

---

## 4. Secure CI/CD Injection via GitHub Secrets

### Encoding Secrets Locally
Before uploading to GitHub Actions Secrets, encode the credential files into Base64:
```bash
# macOS / Linux
base64 -w 0 android/app/src/staging/google-services.json > staging_android.txt
base64 -w 0 ios/config/staging/GoogleService-Info.plist > staging_ios.txt

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/src/staging/google-services.json")) | Set-Content staging_android.txt
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios/config/staging/GoogleService-Info.plist")) | Set-Content staging_ios.txt
```

### GitHub Repository Secrets
Store the encoded strings under:
`Repository Settings -> Secrets and variables -> Actions`:

| Secret Name | Description |
|---|---|
| `FIREBASE_ANDROID_STAGING_BASE64` | Base64 encoded `google-services.json` for Staging |
| `FIREBASE_ANDROID_PROD_BASE64` | Base64 encoded `google-services.json` for Production |
| `FIREBASE_IOS_STAGING_BASE64` | Base64 encoded `GoogleService-Info.plist` for Staging |
| `FIREBASE_IOS_PROD_BASE64` | Base64 encoded `GoogleService-Info.plist` for Production |

### Decoding in GitHub Actions Step
```yaml
      - name: Inject Staging Firebase Configurations
        if: github.ref == 'refs/heads/develop'
        run: |
          mkdir -p aura_app/android/app/src/staging
          mkdir -p aura_app/ios/config/staging
          echo "${{ secrets.FIREBASE_ANDROID_STAGING_BASE64 }}" | base64 --decode > aura_app/android/app/src/staging/google-services.json
          echo "${{ secrets.FIREBASE_IOS_STAGING_BASE64 }}" | base64 --decode > aura_app/ios/config/staging/GoogleService-Info.plist

      - name: Inject Production Firebase Configurations
        if: github.ref == 'refs/heads/main'
        run: |
          mkdir -p aura_app/android/app/src/production
          mkdir -p aura_app/ios/config/production
          echo "${{ secrets.FIREBASE_ANDROID_PROD_BASE64 }}" | base64 --decode > aura_app/android/app/src/production/google-services.json
          echo "${{ secrets.FIREBASE_IOS_PROD_BASE64 }}" | base64 --decode > aura_app/ios/config/production/GoogleService-Info.plist
```

---

## 5. Dart Entrypoint Separation

Create distinct Dart entrypoints targeting each environment:

### `lib/main_staging.dart`
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_staging.dart';
import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptionsStaging.currentPlatform,
  );
  runApp(const AuraApp());
}
```

### `lib/main_production.dart`
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_production.dart';
import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptionsProduction.currentPlatform,
  );
  runApp(const AuraApp());
}
```

---

## 6. Execution & Build Matrix

| Environment | Flutter Run Command | Build Command |
|---|---|---|
| **Staging** | `flutter run --flavor staging -t lib/main_staging.dart` | `flutter build apk --flavor staging -t lib/main_staging.dart` |
| **Production** | `flutter run --flavor production -t lib/main_production.dart` | `flutter build appbundle --flavor production -t lib/main_production.dart` |
