import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.biometricEnabled = true,
  });

  final ThemeMode themeMode;
  final bool biometricEnabled;

  AppSettings copyWith({ThemeMode? themeMode, bool? biometricEnabled}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setBiometricEnabled(bool enabled) {
    state = state.copyWith(biometricEnabled: enabled);
  }
}
