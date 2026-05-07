import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricAuthProvider = Provider<BiometricAuth>((ref) {
  return BiometricAuth();
});

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();
  static bool _isAuthorized = false;

  bool get isAuthorized => _isAuthorized;
  void setAuthorized(bool value) => _isAuthorized = value;

  /// Attempts to authenticate the user biometrically.
  /// Returns [true] if successful, or if biometrics are not available.
  Future<bool> authenticate({String reason = 'Unlock your Second Brain'}) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return true;
    }
  }
}
