import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../controller/ai_runtime_controller.dart';
import '../../repository/ai_model_registry.dart';
import '../../../../core/app_colors.dart';

class AssistantModelSelectorTile extends StatelessWidget {
  const AssistantModelSelectorTile({
    super.key,
    required this.selectedModelId,
    required this.isModelLoaded,
    required this.onModelChanged,
  });

  final String selectedModelId;
  final bool isModelLoaded;
  final ValueChanged<String> onModelChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selected = AiModelRegistry.findById(selectedModelId);

    return GestureDetector(
      onTap: () => _showModelPicker(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_rounded, size: 20, color: colors.textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          selected.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected.id == AiModelRegistry.defaultModel.id) ...[
                        const SizedBox(width: 6),
                        _Badge(label: 'Default', color: colors.isDark ? Colors.purpleAccent : Colors.purple),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${selected.family} · ${selected.parameterCount} · ${selected.sizeLabel}',
                    style: TextStyle(fontSize: 11, color: colors.subtextColor),
                  ),
                ],
              ),
            ),
            if (isModelLoaded) ...[
              const _StatusBadge(label: 'Active', color: Colors.green),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: colors.subtextColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ModelPickerSheet(
        selectedModelId: selectedModelId,
        onModelSelected: onModelChanged,
      ),
    );
  }
}

class _ModelPickerSheet extends ConsumerStatefulWidget {
  const _ModelPickerSheet({
    required this.selectedModelId,
    required this.onModelSelected,
  });

  final String selectedModelId;
  final ValueChanged<String> onModelSelected;

  @override
  ConsumerState<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<_ModelPickerSheet> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(aiRuntimeControllerProvider.notifier).refreshDownloadedModels();
    });
  }

  List<AiModelInfo> get _filteredModels {
    if (_search.isEmpty) return AiModelRegistry.models;
    final q = _search.toLowerCase();
    return AiModelRegistry.models.where((m) {
      return m.displayName.toLowerCase().contains(q) ||
          m.family.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final downloadedModels = ref.watch(aiRuntimeControllerProvider).downloadedModels;
    
    final groupedModels = <String, List<AiModelInfo>>{};
    final downloaded = _filteredModels.where((m) => downloadedModels.contains(m.id)).toList();
    if (downloaded.isNotEmpty) groupedModels['Downloaded'] = downloaded;
    for (final m in _filteredModels) {
      if (downloadedModels.contains(m.id)) continue;
      groupedModels.putIfAbsent(m.family, () => []).add(m);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.subtextColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: colors.textColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Choose a Model',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  style: TextStyle(color: colors.textColor),
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    hintStyle: TextStyle(color: colors.subtextColor),
                    prefixIcon: Icon(Icons.search, size: 20, color: colors.subtextColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.borderColor),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: groupedModels.entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
                  itemBuilder: (context, index) {
                    var cursor = 0;
                    for (final entry in groupedModels.entries) {
                      if (index == cursor) return _FamilyHeader(family: entry.key, count: entry.value.length);
                      cursor++;
                      final modelIndex = index - cursor;
                      if (modelIndex < entry.value.length) {
                        final model = entry.value[modelIndex];
                        return _ModelTile(
                          model: model,
                          isSelected: model.id == widget.selectedModelId,
                          isDownloaded: downloadedModels.contains(model.id),
                          onTap: () {
                            widget.onModelSelected(model.id);
                            Navigator.pop(context);
                          },
                          onDelete: () async {
                            final confirmed = await showDeleteConfirmation(context, itemType: 'Model', itemName: model.displayName);
                            if (confirmed) ref.read(aiRuntimeControllerProvider.notifier).deleteModel(model.id);
                          },
                        );
                      }
                      cursor += entry.value.length;
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({required this.family, required this.count});
  final String family;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            family,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: colors.isDark ? Colors.purpleAccent : Colors.purple),
          ),
          const SizedBox(width: 6),
          Text('($count)', style: TextStyle(fontSize: 11, color: colors.subtextColor)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: colors.borderColor)),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.isSelected,
    required this.isDownloaded,
    required this.onTap,
    required this.onDelete,
  });

  final AiModelInfo model;
  final bool isSelected;
  final bool isDownloaded;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected ? (colors.isDark ? Colors.white12 : Colors.black.withOpacity(0.05)) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.purpleAccent : colors.subtextColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.displayName, style: TextStyle(color: colors.textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      Text(model.description, style: TextStyle(color: colors.subtextColor, fontSize: 11)),
                    ],
                  ),
                ),
                if (isDownloaded) IconButton(icon: const Icon(Icons.delete_outline, size: 20), color: Colors.redAccent, onPressed: onDelete),
                if (!isDownloaded) Text(model.sizeLabel, style: TextStyle(color: colors.subtextColor, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
