import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/vault_model.dart';
import '../../../shared/widgets/section_scaffold.dart';
import '../../vault/controller/vault_controller.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultControllerProvider);
    return vault.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (vault) => SectionScaffold(
        title: 'Documents',
        action: FilledButton.icon(
          onPressed: () => _addDocument(context, ref),
          icon: const Icon(Icons.upload_file),
          label: const Text('Add document'),
        ),
        child: EmptyAwareList(
          isEmpty: vault.documents.isEmpty,
          emptyText: 'No documents saved.',
          child: ListView.separated(
            itemCount: vault.documents.length,
            separatorBuilder: (_, index) => const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final doc = vault.documents[index];
              final theme = Theme.of(context);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconForExt(doc.fileName),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      doc.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      doc.fileName,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onTap: () => DocumentsScreen.openDocument(context, doc),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'View document',
                          onPressed: () =>
                              DocumentsScreen.openDocument(context, doc),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete document',
                          onPressed: () {
                            ref
                                .read(vaultControllerProvider.notifier)
                                .deleteDocument(doc.id);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _iconForExt(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      case 'txt':
        return Icons.article_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'doc', 'docx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;

    // Read file bytes
    Uint8List? fileBytes = file.bytes;
    if (fileBytes == null && file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    }

    // Encode to base64 for persistent storage
    final base64Str = fileBytes != null ? base64Encode(fileBytes) : null;

    // Extract text content for .txt files
    String content = '';
    if ((file.extension ?? '').toLowerCase() == 'txt' && fileBytes != null) {
      content = utf8.decode(fileBytes, allowMalformed: true);
    }

    final title = TextEditingController(
      text: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
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

  static void openDocument(BuildContext context, VaultDocument doc) {
    final ext = doc.fileName.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

    // Try to get bytes from base64 first, then fall back to file path
    Uint8List? bytes;
    if (doc.base64Data != null && doc.base64Data!.isNotEmpty) {
      try {
        bytes = base64Decode(doc.base64Data!);
      } catch (_) {}
    }

    if (isPdf) {
      _openPdfViewer(context, doc.title, bytes, doc.path);
    } else if (isImage) {
      _openImageViewer(context, doc, bytes);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(doc.title)),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  doc.content.isEmpty
                      ? 'Stored file reference:\n${doc.fileName}\n\nPath:\n${doc.path.isEmpty ? 'Imported from picker bytes' : doc.path}'
                      : doc.content,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  static void _openImageViewer(
    BuildContext context,
    VaultDocument doc,
    Uint8List? bytes,
  ) {
    final localFile =
        doc.path.isNotEmpty && File(doc.path).existsSync() ? File(doc.path) : null;

    Widget image;
    if (bytes != null && bytes.isNotEmpty) {
      image = Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _UnavailableDocument(
          message:
              'This image could not be decoded. Re-upload the JPG or save it as PNG.',
          detail: error.toString(),
        ),
      );
    } else if (localFile != null) {
      image = Image.file(
        localFile,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _UnavailableDocument(
          message:
              'This local image file could not be opened. Re-upload the document to store a copy inside the vault.',
          detail: error.toString(),
        ),
      );
    } else {
      image = const _UnavailableDocument(
        message:
            'Image file is no longer available. Re-upload the document to view it.',
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Image preview'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: ColoredBox(
              color: Colors.black,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: image,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openPdfViewer(
    BuildContext context,
    String title,
    Uint8List? bytes,
    String path,
  ) async {
    String? pdfPath;
    try {
      if (bytes != null) {
        final dir = await getTemporaryDirectory();
        final tempFile = File('${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(bytes);
        pdfPath = tempFile.path;
      } else if (path.isNotEmpty && File(path).existsSync()) {
        pdfPath = path;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PDF: $e')),
        );
      }
      return;
    }

    if (pdfPath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file is no longer available. Re-upload it.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: PDFView(
            filePath: pdfPath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
          ),
        ),
      ),
    );
  }
}

class _UnavailableDocument extends StatelessWidget {
  const _UnavailableDocument({
    required this.message,
    this.detail,
  });

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
