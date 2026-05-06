import sys
import re

with open('lib/features/documents/screens/documents_screen.dart', 'r') as f:
    text = f.read()

# Extract from _addDocument to the end of _addDocument
# It ends right before `  static void openDocument`
add_doc_start = text.find("  Future<void> _addDocument")
open_doc_start = text.find("  static void openDocument")
add_doc_code = text[add_doc_start:open_doc_start]

# Extract static methods and end of class DocumentsScreen
unavailable_doc_start = text.find("class _UnavailableDocument")
static_methods_code = text[open_doc_start:unavailable_doc_start]

static_methods_code = static_methods_code.rstrip()
if static_methods_code.endswith('}'):
    static_methods_code = static_methods_code[:-1].rstrip()

unavailable_doc_code = text[unavailable_doc_start:]

new_top = """import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../vault/controller/vault_controller.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();

"""

new_mid = """
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF1E1A25) : const Color(0xFFF9F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF5A49D6)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: Text(
                'Second Brain',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF5A49D6),
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
            colors: isDark
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
              return d.title.toLowerCase().contains(query) ||
                  d.fileName.toLowerCase().contains(query);
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
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Safely storing ${vault.documents.length} sensitive files',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : const Color(0xFF5A5A5A),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _addDocument(context, ref),
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                              label: const Text(
                                'Upload Document',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2533) : const Color(0xFFFAF7FF),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Search documents...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF9E8DB3),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.search,
                                    color: isDark ? Colors.white54 : const Color(0xFF9E8DB3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: filteredDocs.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40.0),
                              child: Center(
                                child: Text(
                                  'No documents found.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF6B5A8E),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final doc = filteredDocs[index];
                                return _buildDocumentCard(context, ref, doc, isDark);
                              },
                              childCount: filteredDocs.length,
                            ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, WidgetRef ref, VaultDocument doc, bool isDark) {
    final ext = doc.fileName.split('.').last.toLowerCase();
    
    IconData iconData;
    Color iconColor;
    Color iconBgColor;

    if (ext == 'pdf') {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = const Color(0xFFE53935);
      iconBgColor = const Color(0xFFFFEBEE);
    } else if (['png', 'jpg', 'jpeg'].contains(ext)) {
      iconData = Icons.image_outlined;
      iconColor = const Color(0xFF1E88E5);
      iconBgColor = const Color(0xFFE3F2FD);
    } else if (['txt', 'doc', 'docx'].contains(ext)) {
      iconData = Icons.article_outlined;
      iconColor = const Color(0xFF5E35B1);
      iconBgColor = const Color(0xFFEDE7F6);
    } else if (['zip', 'rar', 'tar'].contains(ext)) {
      iconData = Icons.folder_zip_outlined;
      iconColor = const Color(0xFFF57C00);
      iconBgColor = const Color(0xFFFFF3E0);
    } else {
      iconData = Icons.description_outlined;
      iconColor = const Color(0xFF5A5A5A);
      iconBgColor = const Color(0xFFEEEEEE);
    }

    if (isDark) {
      iconBgColor = iconColor.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2435).withOpacity(0.8) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFFE2D8F0).withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(iconData, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  doc.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  doc.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF8C8C8C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => DocumentsScreen.openDocument(context, doc),
            icon: Icon(Icons.visibility_outlined, color: isDark ? Colors.white54 : const Color(0xFF8C8C8C), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'View document',
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : const Color(0xFF8C8C8C), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDeleteConfirmation(
                  context,
                  itemType: 'Document',
                  itemName: doc.title,
                );
                if (confirmed && context.mounted) {
                  ref.read(vaultControllerProvider.notifier).deleteDocument(doc.id);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

"""

with open('lib/features/documents/screens/documents_screen.dart', 'w') as f:
    f.write(new_top + static_methods_code + "\n\n" + new_mid + add_doc_code + "\n}\n\n" + unavailable_doc_code)

