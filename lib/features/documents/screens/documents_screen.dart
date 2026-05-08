import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../vault/controller/vault_controller.dart';
import '../../../core/app_colors.dart';
import 'widgets/document_card.dart';
import 'widgets/document_viewer.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();

  static void openDocument(BuildContext context, VaultDocument doc) {
    DocumentViewer.openDocument(context, doc);
  }
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final uuid = const Uuid();

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
      appBar: AppBar(
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
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: colors.isDark ? Colors.white : const Color(0xFF5A49D6),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
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
            final filteredDocs = vault.documents.where((d) {
              final query = _searchQuery.toLowerCase();
              return d.title.toLowerCase().contains(query) || d.fileName.toLowerCase().contains(query);
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
                          Text(
                            'Documents',
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w500,
                              color: colors.textColor,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Safely storing ${vault.documents.length} sensitive files',
                            style: TextStyle(fontSize: 16, color: colors.subtextColor),
                          ),
                          const SizedBox(height: 24),
                          _buildUploadButton(context, ref),
                          const SizedBox(height: 24),
                          _buildSearchField(colors),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  _buildDocumentsList(filteredDocs, colors),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadButton(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _addDocument(context, ref),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
        label: const Text('Upload Document', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF2C2533) : const Color(0xFFFAF7FF),
        borderRadius: BorderRadius.circular(32),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(color: colors.textColor),
        decoration: InputDecoration(
          hintText: 'Search documents...',
          hintStyle: TextStyle(color: colors.subtextColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(Icons.search, color: colors.subtextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsList(List<VaultDocument> filteredDocs, AppColors colors) {
    if (filteredDocs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Center(child: Text('No documents found.', style: TextStyle(color: colors.subtextColor))),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => DocumentCard(doc: filteredDocs[index]),
          childCount: filteredDocs.length,
        ),
      ),
    );
  }

  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'doc', 'docx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;

    Uint8List? fileBytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    final base64Str = fileBytes != null ? base64Encode(fileBytes) : null;
    String content = (file.extension ?? '').toLowerCase() == 'txt' && fileBytes != null ? utf8.decode(fileBytes, allowMalformed: true) : '';

    final title = TextEditingController(text: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
    if (!context.mounted) return;
    final document = await showDialog<VaultDocument>(
      context: context,
      builder: (context) => EditDialog(
        title: 'Save document',
        fields: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          Text('File: ${file.name}'),
        ],
        onSave: () => VaultDocument(
          id: uuid.v4(),
          title: title.text.trim(),
          fileName: file.name,
          path: file.path ?? '',
          content: content,
          addedAt: DateTime.now(),
          base64Data: base64Str,
        ),
      ),
    );
    if (document == null || document.title.isEmpty) return;
    await ref.read(vaultControllerProvider.notifier).addDocument(document);
  }
}
