# Aura Dating App — Google Play Beta Deployment Guide 🚀
*Principal DevOps & Cloud Architecture Runbook*

---

## Executive Overview
This guide provides an end-to-end production deployment roadmap for releasing the **Aura Dating App** (`com.auraapp.aura_app`) to the **Google Play Console (Internal / Closed Beta Testing Track)**.

---

## 1. Prerequisites Checklist
- [x] Flutter SDK installed (`>=3.0.0`)
- [x] Android SDK (Build Tools, Platform SDK 34 / Android 14)
- [x] Java JDK 17+ configured in `JAVA_HOME`
- [x] Firebase Project created with Authentication & Cloud Firestore enabled
- [x] Google Play Developer Console account with Administrator or Release Manager permissions

---

## 2. Production Keystore Generation & Signing Setup

### Step 2.1: Generate Production Keystore
Open a PowerShell or Terminal window and run the `keytool` utility (bundled with Java JDK) to create your production release keystore:

```powershell
keytool -genkey -v -keystore e:\Sanjayprojects\Datingapp\aura_app\android\app\upload-keystore.jks `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias aura-upload-key
```
> **Security Rule**: Keep this keystore file and its passwords strictly confidential. **Never commit `.jks` files or `key.properties` to version control!** Both are pre-configured in `.gitignore`.

### Step 2.2: Configure `key.properties`
Create `aura_app/android/key.properties` (a template is available at `aura_app/android/key.properties.example`):

```properties
storePassword=YourKeystorePasswordHere
keyPassword=YourKeyPasswordHere
keyAlias=aura-upload-key
storeFile=upload-keystore.jks
```

*Note: The Gradle build configuration (`android/app/build.gradle.kts`) automatically detects `key.properties`. If absent or pointing to an uncreated keystore file, Gradle safely falls back to debug signing to enable developer test builds.*

---

## 3. Firebase & Cloud Firestore Production Deployment

### Step 3.1: Verify Firebase Configuration
The Android app is configured with `google-services.json` at:
`aura_app/android/app/google-services.json`
Package name: `com.auraapp.aura_app`

### Step 3.2: Deploy Firestore Security Rules
Ensure strict security rules are deployed to Firebase:
```powershell
# From workspace root
firebase login
firebase deploy --only firestore:rules
```

### Step 3.3: Firestore Collections Architecture
1. **`/users/{userId}`**: Stores authenticated profile info, photos, verification badges, preferences, and FCM tokens.
2. **`/profiles/{profileId}`**: Stores public radar discovery cards with 9-character precision Geohashes (`geohash`), coordinates, and discovery tags.
3. **`/conversations/{conversationId}`**: Two-way chat metadata with participant array and unread counters.
4. **`/conversations/{conversationId}/messages/{messageId}`**: AES-256-CBC end-to-end encrypted chat payloads with TTL purge timestamps (`expiresAt`).
5. **`/support_tickets/{ticketId}`**: Automated user dispute, report, and helpdesk intake pipeline with priority routing.

---

## 4. Building the Release App Bundle (.aab)

Google Play Store requires Android App Bundles (`.aab`) for production distribution to optimize dynamic delivery and APK splitting per device architecture.

Run the following command from the `aura_app` directory:

```powershell
cd e:\Sanjayprojects\Datingapp\aura_app

# Clean previous build artifacts
flutter clean

# Fetch dependencies
flutter pub get

# Compile release Android App Bundle
flutter build appbundle --release
```

Once compilation completes, your production bundle will be located at:
```
aura_app/build/app/outputs/bundle/release/app-release.aab
```

*(Optional Test APK)*: To generate an APK for immediate direct sideloading and physical device QA:
```powershell
flutter build apk --release
# Output: aura_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Google Play Console Release Flow

### Step 5.1: Create Application
1. Log in to [Google Play Console](https://play.google.com/console).
2. Click **Create app**:
   - **App name**: Aura - Modern Romantic Dating
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free
   - Accept the Developer Program Policies and US export laws.

### Step 5.2: Set Up Internal / Closed Testing Track
1. In the left navigation, navigate to **Testing** > **Internal testing** (or **Closed testing**).
2. Click **Create new release**.
3. Under **App integrity**, opt into **Play App Signing** (Google automatically secures your app signing key).
4. Drag and drop `app-release.aab` from `aura_app/build/app/outputs/bundle/release/`.
5. Enter a **Release name** (e.g., `1.0.0 (1) - Internal Beta Release`).
6. Enter **Release notes**:
   ```
   Aura Beta v1.0.0
   - Modern romantic UI & Dynamic Proximity Radar
   - Real-time end-to-end encrypted messaging with auto-purge TTL
   - Advanced profile cards and instant gift interactions
   - Built-in secure helpdesk & safety reporting
   ```
7. Click **Save** and then **Review release**.

### Step 5.3: Testers Configuration
1. Go to the **Testers** tab in Internal Testing.
2. Click **Create email list** (e.g., `aura-beta-testers`).
3. Add the email addresses of your QA team and stakeholders.
4. Copy the **Join on Android** or **Join on the web** opt-in URL and share it with your beta testers.

---

## 6. Permissions & Security Declarations

When completing the Google Play **App Content** declarations, refer to the verified app configuration:

| Permission | Purpose & Declaration in Play Console |
| :--- | :--- |
| `ACCESS_FINE_LOCATION` | Proximity radar matchmaking and real-time distance calculation. Declare under Location permissions. |
| `ACCESS_COARSE_LOCATION` | Fallback approximate location for privacy-oriented discovery. |
| `CAMERA` | Real-time selfie verification, identity trust score, and profile picture upload. |
| `RECORD_AUDIO` | Voice notes in chat and secure audio calling. |
| `INTERNET` | Firebase Auth, Firestore real-time synchronization, and Cloud Messaging. |

### FLAG_SECURE Protection:
To protect sensitive private dating chats and prevent non-consensual media capture, `FLAG_SECURE` is programmatically activated on chat screens:
- Blocks screenshot capture on Android.
- Prevents screen recording during active sessions.
- Obfuscates the app preview in Android Recent Tasks switcher.

---

## 7. Troubleshooting & Verification

- **Gradle signing fails**: Ensure `upload-keystore.jks` is placed in `aura_app/android/app/` or specify an absolute path in `key.properties`.
- **Firebase Auth errors**: Verify SHA-1 and SHA-256 fingerprint hashes from your keystore are added to the Firebase Console:
  ```powershell
  keytool -list -v -keystore aura_app/android/app/upload-keystore.jks -alias aura-upload-key
  ```
- **Firestore Permission Denied**: Deploy `firestore.rules` and verify Firebase Authentication token validity.
