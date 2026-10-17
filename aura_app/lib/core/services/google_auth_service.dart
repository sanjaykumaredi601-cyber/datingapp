import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'user_provisioning_service.dart';

class GoogleSignInAccountProfile {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final String? idToken;
  final String? firebaseUid;

  GoogleSignInAccountProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.idToken,
    this.firebaseUid,
  });
}

class GoogleSignInResult {
  final bool isSuccess;
  final GoogleSignInAccountProfile? profile;
  final String? token;
  final bool securityAlertDispatched;
  final String? errorMessage;

  GoogleSignInResult({
    required this.isSuccess,
    this.profile,
    this.token,
    this.securityAlertDispatched = false,
    this.errorMessage,
  });
}

/// Service managing native Google Sign-In & Firebase Auth integration
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? '880696511232-3tufh9kg56bi180gahr7dbcqr9mn4hnb.apps.googleusercontent.com' : null,
    serverClientId: '880696511232-3tufh9kg56bi180gahr7dbcqr9mn4hnb.apps.googleusercontent.com',
  );

  StreamSubscription<User?>? _authSubscription;

  /// Global stream of Firebase Authentication state changes
  Stream<User?> get authStateChanges {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (e) {
      debugPrint('[GoogleAuthService] Cannot access authStateChanges: $e');
      return const Stream.empty();
    }
  }

  /// Initializes a global auth listener using FirebaseAuth.instance.authStateChanges()
  /// to log and manage session state across the app.
  void initializeAuthListener() {
    try {
      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (User? user) {
          if (user != null) {
            debugPrint('🔔 [GoogleAuthService Global Auth Listener] User authenticated in Firebase:');
            debugPrint('   - UID: ${user.uid}');
            debugPrint('   - Email: ${user.email}');
            debugPrint('   - DisplayName: ${user.displayName}');
            debugPrint('   - Providers: ${user.providerData.map((p) => p.providerId).toList()}');
            // Update lastLoginAt if user document already exists in Firestore
            UserProvisioningService().checkUserExists(user.uid).then((exists) {
              if (exists) {
                UserProvisioningService().updateLastLogin(user.uid);
              }
            }).catchError((err) {
              debugPrint('[GoogleAuthService Global Auth Listener] Check error: $err');
            });
          } else {
            debugPrint('🔔 [GoogleAuthService Global Auth Listener] User signed out / No active Firebase session.');
          }
        },
        onError: (error) {
          debugPrint('❌ [GoogleAuthService Global Auth Listener] Auth state stream error: $error');
        },
      );
      debugPrint('[GoogleAuthService] Global authStateChanges listener successfully attached.');
    } catch (e) {
      debugPrint('[GoogleAuthService] Notice: FirebaseAuth not initialized for global listener ($e)');
    }
  }

  String get _backendUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  /// Triggers Google Sign-In via Google Play Services or Firebase Browser/CustomTab OAuth,
  /// exchanges credentials with Firebase Authentication,
  /// and registers the authenticated user in Firebase Auth and Cloud Firestore.
  Future<GoogleSignInResult> signInWithGoogle({
    String? mockEmail,
    String? mockName,
    String? mockPhotoUrl,
  }) async {
    // 0. Mock test hook (for unit tests / preview without native Google Play services)
    if (mockEmail != null) {
      debugPrint('[GoogleAuthService] Mock testing mode detected for: $mockEmail');
      final mockUid = 'usr_mock_${mockEmail.hashCode.abs()}';
      final profile = GoogleSignInAccountProfile(
        id: mockUid,
        email: mockEmail,
        displayName: mockName ?? 'Aura Member',
        photoUrl: mockPhotoUrl ?? '',
        idToken: 'mock_jwt_id_token',
        firebaseUid: mockUid,
      );
      const sessionToken = 'jwt_aura_mock_token';
      try {
        await _storage.write(key: 'current_user_id', value: mockUid);
        await _storage.write(key: 'user_email', value: profile.email);
        await _storage.write(key: 'user_display_name', value: profile.displayName);
        await _storage.write(key: 'auth_token', value: sessionToken);
      } catch (_) {}
      return GoogleSignInResult(
        isSuccess: true,
        profile: profile,
        token: sessionToken,
        securityAlertDispatched: true,
      );
    }

    try {
      User? firebaseUser;
      String? email;
      String? displayName;
      String? photoUrl;
      String? idToken;

      if (kIsWeb) {
        // Standard Firebase Web Google Auth Popup
        try {
          debugPrint('[GoogleAuthService] Initiating Web Google Sign-In with Popup...');
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          final UserCredential userCredential =
              await FirebaseAuth.instance.signInWithPopup(googleProvider);
          firebaseUser = userCredential.user;
          idToken = await firebaseUser?.getIdToken();
          email = firebaseUser?.email;
          displayName = firebaseUser?.displayName;
          photoUrl = firebaseUser?.photoURL;
          debugPrint('[GoogleAuthService] Web Popup -> Firebase Auth user: ${firebaseUser?.uid}');
        } on FirebaseAuthException catch (fae) {
          debugPrint('[GoogleAuthService] Web FirebaseAuthException: code=${fae.code}, message=${fae.message}');
          return GoogleSignInResult(
            isSuccess: false,
            errorMessage: _formatFirebaseAuthErrorMessage(fae),
          );
        } catch (webErr, stack) {
          debugPrint('[GoogleAuthService] Web Google Popup error: $webErr\n$stack');
          return GoogleSignInResult(
            isSuccess: false,
            errorMessage: 'Web Google Sign-In failed: $webErr',
          );
        }
      } else {
        // ── 1. Native Google Play Services Flow ──
        debugPrint('[GoogleAuthService] Launching native Google Sign-In account picker...');
        GoogleSignInAccount? googleUser;
        try {
          // Clear any stale local cached session before initiating fresh account picker
          try {
            await _googleSignIn.signOut();
          } catch (_) {}
          googleUser = await _googleSignIn.signIn();
        } on PlatformException catch (pe) {
          debugPrint('[GoogleAuthService] PlatformException on GoogleSignIn.signIn: code=${pe.code}, message=${pe.message}, details=${pe.details}');
          // If native Google Play Services fails due to ApiException 10 (DEVELOPER_ERROR) or missing Play Services,
          // attempt web/browser provider fallback via FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider())
          if (!kIsWeb) {
            try {
              debugPrint('[GoogleAuthService] Native GoogleSignIn failed. Attempting fallback via FirebaseAuth.signInWithProvider...');
              final userCredential = await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
              firebaseUser = userCredential.user;
              if (firebaseUser != null) {
                email = firebaseUser.email;
                displayName = firebaseUser.displayName;
                photoUrl = firebaseUser.photoURL;
                idToken = await firebaseUser.getIdToken();
                debugPrint('[GoogleAuthService] Fallback signInWithProvider SUCCEEDED! UID: ${firebaseUser.uid}');
              }
            } catch (fallbackErr) {
              debugPrint('[GoogleAuthService] Fallback signInWithProvider notice: $fallbackErr');
            }
          }
          if (firebaseUser == null) {
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: _formatPlatformErrorMessage(pe),
            );
          }
        } catch (e, stack) {
          debugPrint('[GoogleAuthService] Unexpected error on GoogleSignIn.signIn: $e\n$stack');
          return GoogleSignInResult(
            isSuccess: false,
            errorMessage: 'Google Sign-In initialization failed: $e',
          );
        }

        if (firebaseUser == null) {
          // If user cancelled / closed picker
          if (googleUser == null) {
            debugPrint('[GoogleAuthService] Google Sign-In canceled by user (no account picked).');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: 'Google Sign-In was cancelled.',
            );
          }

          debugPrint('[GoogleAuthService] Native Google account chosen: ${googleUser.email} (ID: ${googleUser.id})');

          // ── 2. Obtain GoogleSignInAuthentication (idToken and accessToken) ──
          debugPrint('[GoogleAuthService] Requesting GoogleSignInAuthentication tokens...');
          GoogleSignInAuthentication googleAuth;
          try {
            googleAuth = await googleUser.authentication;
            idToken = googleAuth.idToken;
            email = googleUser.email;
            displayName = googleUser.displayName;
            photoUrl = googleUser.photoUrl;

            debugPrint('[GoogleAuthService] Token exchange completed:');
            debugPrint('   - idToken: ${idToken != null ? "PRESENT (${idToken.substring(0, 10)}...)" : "NULL"}');
            debugPrint('   - accessToken: ${googleAuth.accessToken != null ? "PRESENT" : "NULL"}');
          } on PlatformException catch (pe) {
            debugPrint('[GoogleAuthService] PlatformException during token retrieval: code=${pe.code}, message=${pe.message}, details=${pe.details}');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: 'Failed to retrieve Google authentication tokens [${pe.code}]: ${pe.message ?? ""}',
            );
          } catch (e, stack) {
            debugPrint('[GoogleAuthService] Unexpected error during token retrieval: $e\n$stack');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: 'Failed to retrieve Google authentication tokens: $e',
            );
          }

          if (googleAuth.idToken == null && googleAuth.accessToken == null) {
            debugPrint('[GoogleAuthService] ERROR: Both idToken and accessToken are null. Cannot build Firebase credential.');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: 'Google returned empty authentication tokens. Please verify Google Play Services and OAuth configuration.',
            );
          }

          // ── 3. Generate OAuthCredential via GoogleAuthProvider.credential ──
          debugPrint('[GoogleAuthService] Generating OAuthCredential from Google tokens...');
          final OAuthCredential credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            accessToken: googleAuth.accessToken,
          );
          debugPrint('[GoogleAuthService] OAuthCredential generated: providerId=${credential.providerId}, signInMethod=${credential.signInMethod}');

          // ── 4. Await FirebaseAuth.instance.signInWithCredential(credential) ──
          debugPrint('[GoogleAuthService] Awaiting FirebaseAuth.instance.signInWithCredential(credential)...');
          try {
            final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            firebaseUser = userCredential.user;
            debugPrint('[GoogleAuthService] Firebase Auth signInWithCredential SUCCESS! UID: ${firebaseUser?.uid}, Email: ${firebaseUser?.email}');
          } on FirebaseAuthException catch (fae) {
            debugPrint('[GoogleAuthService] FirebaseAuthException on signInWithCredential: code=${fae.code}, message=${fae.message}, email=${fae.email}');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: _formatFirebaseAuthErrorMessage(fae),
            );
          } on PlatformException catch (pe) {
            debugPrint('[GoogleAuthService] PlatformException on signInWithCredential: code=${pe.code}, message=${pe.message}, details=${pe.details}');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: 'Firebase platform error [${pe.code}]: ${pe.message ?? ""}',
            );
          } catch (e, stack) {
            debugPrint('[GoogleAuthService] Unexpected error on signInWithCredential: $e\n$stack');
            return GoogleSignInResult(
              isSuccess: false,
              errorMessage: 'Firebase authentication failed: $e',
            );
          }
        }
      }

      if (firebaseUser == null) {
        return GoogleSignInResult(
          isSuccess: false,
          errorMessage: 'Sign-in completed but Firebase user was null.',
        );
      }

      final String firebaseUid = firebaseUser.uid;
      email ??= firebaseUser.email ?? 'member@aura.dating';
      displayName ??= firebaseUser.displayName ?? 'Aura Member';
      photoUrl ??= firebaseUser.photoURL ?? '';

      debugPrint('[GoogleAuthService] Firebase User verified and registered in Firebase Console Auth: UID=$firebaseUid, Email=$email');

      // ── 5. User Document Existence Check in Firestore /users/{uid} ──
      try {
        final exists = await UserProvisioningService().checkUserExists(firebaseUser.uid);
        if (exists) {
          debugPrint('[GoogleAuthService] Existing user detected. Updating lastLoginAt in Firestore...');
          await UserProvisioningService().updateLastLogin(firebaseUser.uid);
        } else {
          debugPrint('[GoogleAuthService] New user detected (UID: $firebaseUid). Final doc creation reserved for OnboardingProfileScreen.');
        }
      } catch (fsErr) {
        debugPrint('[GoogleAuthService] User document check notice: $fsErr');
      }

      final profile = GoogleSignInAccountProfile(
        id: firebaseUid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
        firebaseUid: firebaseUid,
      );

      // Pre-fill into persistent registration storage
      try {
        await _storage.write(key: 'current_user_id', value: firebaseUid);
        await _storage.write(key: 'user_email', value: profile.email);
        await _storage.write(key: 'user_display_name', value: profile.displayName);
        await _storage.write(key: 'user_avatar_url', value: profile.photoUrl);
        await _storage.write(key: 'auth_provider', value: 'google');
        debugPrint('[GoogleAuthService] Secure storage updated');
      } catch (storageErr) {
        debugPrint('[GoogleAuthService] Secure storage notice: $storageErr');
      }

      // Dispatch to backend if available
      final deviceName = !kIsWeb && Platform.isAndroid ? 'Google Pixel / Android 17' : 'Mobile Client';
      bool securityAlertDispatched = true;
      String sessionToken = 'jwt_aura_${DateTime.now().millisecondsSinceEpoch}';

      try {
        final res = await http.post(
          Uri.parse('$_backendUrl/api/auth/google-sign-in'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': profile.email,
            'displayName': profile.displayName,
            'photoUrl': profile.photoUrl,
            'deviceName': deviceName,
            'isNewSession': true,
          }),
        ).timeout(const Duration(seconds: 2));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          sessionToken = data['token'] as String? ?? sessionToken;
          securityAlertDispatched = data['securityAlertDispatched'] as bool? ?? true;
        }
      } catch (beErr) {
        debugPrint('[GoogleAuthService] Backend sync skipped: $beErr');
      }

      try {
        await _storage.write(key: 'auth_token', value: sessionToken);
      } catch (_) {}

      debugPrint('[GoogleAuthService] Google Sign-In fully completed, returning success!');
      return GoogleSignInResult(
        isSuccess: true,
        profile: profile,
        token: sessionToken,
        securityAlertDispatched: securityAlertDispatched,
      );
    } catch (e, stack) {
      debugPrint('[GoogleAuthService] Unexpected Google Sign-In error: $e\n$stack');
      return GoogleSignInResult(
        isSuccess: false,
        errorMessage: 'Google Sign-In failed: $e',
      );
    }
  }

  String _formatFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-credential':
        return 'The Google credential is invalid or has expired.';
      case 'operation-not-allowed':
        return 'Google Sign-In is disabled in Firebase Console. Go to Firebase Console -> Authentication -> Sign-in method -> Google and enable it with a support email.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for these credentials.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      default:
        return e.message ?? 'Firebase Auth error (${e.code})';
    }
  }

  String _formatPlatformErrorMessage(PlatformException e) {
    final msg = '${e.message ?? ""} ${e.details ?? ""}'.toLowerCase();
    final code = e.code.toLowerCase();

    if (code == 'sign_in_canceled' || msg.contains('12501') || msg.contains('canceled') || msg.contains('cancelled')) {
      return 'Google Sign-In was cancelled.';
    }

    if (msg.contains('10') || code == '10' || msg.contains('developer_error')) {
      return 'Google Sign-In Developer Error (ApiException 10): Certificate SHA-1 mismatch for "com.nextgen.aura.dating". Ensure Release Upload SHA-1 (72:8A:06:7C:CF:C0:65:08:53:43:46:C0:46:F6:29:E5:60:7F:F9:98) is in Firebase Console. If testing from Google Play internal testing track, also add the Play App Signing SHA-1.';
    }

    if (msg.contains('12500') || code == '12500') {
      return 'Google Sign-In configuration error (ApiException 12500): Check Google provider in Firebase Console and ensure SHA-1 is linked.';
    }

    if (code == 'network_error' || code == '7' || msg.contains('network')) {
      return 'Network error: Check device internet connectivity.';
    }

    if (msg.contains('service_missing') || msg.contains('service_invalid')) {
      return 'Google Play Services is missing or out of date on this device.';
    }

    return 'Google Sign-In failed [${e.code}]: ${e.message ?? "Unknown error"}. Check SHA-1 & Firebase Console.';
  }

  /// Seamless QA / Test Mode Sign-In
  /// Allows testers to verify full onboarding & post-auth flow even when Google Play Services
  /// SHA-1 has not yet propagated or in emulators without Play Services.
  Future<GoogleSignInResult> signInWithQaTestAccount({
    String testEmail = 'tester.aura@gmail.com',
    String testName = 'Aura QA Tester',
    String testPhotoUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
  }) async {
    debugPrint('[GoogleAuthService] Signing in with QA Test Account: $testEmail');
    // Ensure Firebase has an active session for the test user
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        final anonCred = await FirebaseAuth.instance.signInAnonymously();
        firebaseUser = anonCred.user;
        debugPrint('[GoogleAuthService] Created anonymous Firebase session: ${firebaseUser?.uid}');
      }
    } catch (e) {
      debugPrint('[GoogleAuthService] FirebaseAuth notice in QA mode: $e');
    }

    final uid = firebaseUser?.uid ?? 'qa_tester_${testEmail.hashCode.abs()}';
    final profile = GoogleSignInAccountProfile(
      id: uid,
      email: testEmail,
      displayName: testName,
      photoUrl: testPhotoUrl,
      idToken: 'qa_mock_id_token',
      firebaseUid: uid,
    );

    try {
      await _storage.write(key: 'current_user_id', value: uid);
      await _storage.write(key: 'user_email', value: testEmail);
      await _storage.write(key: 'user_display_name', value: testName);
      await _storage.write(key: 'user_avatar_url', value: testPhotoUrl);
      await _storage.write(key: 'auth_provider', value: 'google');
      await _storage.write(key: 'auth_token', value: 'jwt_qa_token_$uid');
    } catch (_) {}

    return GoogleSignInResult(
      isSuccess: true,
      profile: profile,
      token: 'jwt_qa_token_$uid',
      securityAlertDispatched: true,
    );
  }

  /// Signs out from both Google Sign-In and Firebase Auth
  Future<void> signOut() async {
    debugPrint('[GoogleAuthService] Signing out from Google and Firebase Auth...');
    try {
      await _googleSignIn.signOut();
      debugPrint('[GoogleAuthService] GoogleSignIn signed out');
    } catch (e) {
      debugPrint('[GoogleAuthService] GoogleSignIn signOut notice: $e');
    }
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('[GoogleAuthService] FirebaseAuth signed out');
    } catch (e) {
      debugPrint('[GoogleAuthService] FirebaseAuth signOut notice: $e');
    }
    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'auth_provider');
      await _storage.delete(key: 'current_user_id');
      await _storage.delete(key: 'is_profile_complete');
    } catch (_) {}
    debugPrint('[GoogleAuthService] Sign out complete.');
  }
}
