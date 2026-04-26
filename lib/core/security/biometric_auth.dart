import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricAuthProvider = Provider<BiometricAuth>((ref) {
  return BiometricAuth();
});

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Attempts to authenticate the user biometrically.
  /// Returns [true] if successful, or if biometrics are not available.
  Future<bool> authenticate({String reason = 'Unlock your Second Brain'}) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        // If the device doesn't support biometrics, bypass.
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // fallback to device credentials
        ),
      );
    } on PlatformException catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }
}
