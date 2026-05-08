import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/vault_model.dart';
import '../../vault/controller/vault_controller.dart';
import '../../../core/app_colors.dart';
import 'widgets/password_card.dart';
import 'widgets/add_password_dialog.dart';

class PasswordsScreen extends ConsumerStatefulWidget {
  const PasswordsScreen({super.key});

  @override
  ConsumerState<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends ConsumerState<PasswordsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultAsync = ref.watch(vaultControllerProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colors.bgColor,
      appBar: _buildAppBar(context, colors),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors.isDark
                ? [const Color(0xFF1E1A25), const Color(0xFF120F16)]
                : [const Color(0xFFF9F5FF), const Color(0xFFEBE0FA)],
          ),
        ),
        child: vaultAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(error.toString())),
          data: (vault) {
            final filtered = vault.passwords.where((p) {
              final q = _searchQuery.toLowerCase();
              return p.accountName.toLowerCase().contains(q) || p.username.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('Passwords', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w500, color: colors.textColor, letterSpacing: -1)),
                          const SizedBox(height: 8),
                          Text('Securing ${vault.passwords.length} credentials', style: TextStyle(fontSize: 16, color: colors.subtextColor)),
                          const SizedBox(height: 24),
                          _buildAddButton(context),
                          const SizedBox(height: 24),
                          _buildSearchField(colors),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildList(filtered, colors),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppColors colors) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: colors.isDark ? Colors.white : const Color(0xFF5A49D6)),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: Center(
            child: Text('Second Brain', style: GoogleFonts.inter(color: colors.isDark ? Colors.white : const Color(0xFF5A49D6), fontWeight: FontWeight.w700, fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _addPassword(context, ref),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
        label: const Text('Add Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return Container(
      decoration: BoxDecoration(color: colors.surfaceColor, borderRadius: BorderRadius.circular(32)),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: colors.textColor),
        decoration: InputDecoration(
          hintText: 'Search passwords...',
          hintStyle: TextStyle(color: colors.subtextColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.search, color: colors.subtextColor)),
        ),
      ),
    );
  }

  Widget _buildList(List filtered, AppColors colors) {
    if (filtered.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 40.0), child: Center(child: Text('No passwords found.', style: TextStyle(color: colors.subtextColor)))));
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => PasswordCard(
            password: filtered[index],
            onEdit: () => _editPassword(context, ref, filtered[index]),
          ),
          childCount: filtered.length,
        ),
      ),
    );
  }

  Future<void> _addPassword(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<VaultPassword>(
      context: context,
      builder: (context) => const CustomPasswordDialog(),
    );
    if (result != null) {
      await ref.read(vaultControllerProvider.notifier).upsertPassword(result);
    }
  }

  Future<void> _editPassword(BuildContext context, WidgetRef ref, VaultPassword password) async {
    final result = await showDialog<VaultPassword>(
      context: context,
      builder: (context) => CustomPasswordDialog(item: password),
    );
    if (result != null) {
      await ref.read(vaultControllerProvider.notifier).upsertPassword(result);
    }
  }
}
