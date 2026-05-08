import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:second_brain_app/features/vault/repository/vault_repository.dart';

import '../../../core/security/biometric_auth.dart';
import '../../settings/controller/settings_controller.dart';
import '../../../core/app_colors.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/dashboard_search_bar.dart';
import 'widgets/dashboard_action_buttons.dart';
import 'widgets/dashboard_notes_list.dart';
import 'widgets/dashboard_bottom_input.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiController = TextEditingController();
  String _searchQuery = '';
  bool _isAuthorized = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    Future.microtask(() => _checkBiometricLock());
  }

  Future<void> _checkBiometricLock() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final settings = ref.read(settingsControllerProvider);

    final biometricAuth = ref.read(biometricAuthProvider);
    if (!settings.biometricEnabled || biometricAuth.isAuthorized) {
      if (mounted) {
        setState(() {
          _isAuthorized = true;
          _isCheckingAuth = false;
        });
      }
      return;
    }

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock your Second Brain',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        ref.read(vaultRepositoryProvider).markAsAuthenticated();
      }

      if (mounted) {
        setState(() {
          _isAuthorized = didAuthenticate;
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      if (mounted) {
        setState(() {
          _isAuthorized = false;
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    
    if (_isCheckingAuth) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, size: 48, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Second Brain is Locked',
                style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please authenticate to continue'),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _checkBiometricLock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock Now'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bgColor,
      resizeToAvoidBottomInset: true,
      appBar: const DashboardAppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardSearchBar(controller: _searchController),
                  const SizedBox(height: 16),
                  const DashboardActionButtons(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/notes/add'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: colors.passwordsColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.post_add,
                            size: 20,
                            color: Color(0xFFD388FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          DashboardNotesList(searchQuery: _searchQuery),
        ],
      ),
      bottomNavigationBar: DashboardBottomInput(controller: _aiController),
    );
  }
}
