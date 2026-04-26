import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  static const _storage = FlutterSecureStorage();
  static const _themeModeKey = 'settings_theme_mode';
  static const _biometricEnabledKey = 'settings_biometric_enabled';

  @override
  AppSettings build() {
    Future.microtask(_load);
    return const AppSettings();
  }

  Future<void> _load() async {
    final themeValue = await _storage.read(key: _themeModeKey);
    final biometricValue = await _storage.read(key: _biometricEnabledKey);
    state = AppSettings(
      themeMode: _parseThemeMode(themeValue),
      biometricEnabled: biometricValue == null
          ? state.biometricEnabled
          : biometricValue == 'true',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _storage.write(key: _themeModeKey, value: mode.name);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  ThemeMode _parseThemeMode(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
