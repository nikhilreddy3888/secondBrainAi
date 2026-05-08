import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../models/vault_model.dart';

class DocumentViewer {
  static void openDocument(BuildContext context, VaultDocument doc) {
    final ext = doc.fileName.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

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

  static void _openImageViewer(BuildContext context, VaultDocument doc, Uint8List? bytes) {
    final localFile = doc.path.isNotEmpty && File(doc.path).existsSync() ? File(doc.path) : null;

    Widget image;
    if (bytes != null && bytes.isNotEmpty) {
      image = Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _UnavailableDocument(
          message: 'This image could not be decoded. Re-upload the JPG or save it as PNG.',
          detail: error.toString(),
        ),
      );
    } else if (localFile != null) {
      image = Image.file(
        localFile,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _UnavailableDocument(
          message: 'This local image file could not be opened. Re-upload the document to store a copy inside the vault.',
          detail: error.toString(),
        ),
      );
    } else {
      image = const _UnavailableDocument(
        message: 'Image file is no longer available. Re-upload the document to view it.',
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
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(child: image),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openPdfViewer(BuildContext context, String title, Uint8List? bytes, String path) async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
      }
      return;
    }

    if (pdfPath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF file is no longer available.')));
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
  const _UnavailableDocument({required this.message, this.detail});
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
