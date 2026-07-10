import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/ui/pages/settings/widgets/color_picker.dart';
import 'package:mytime/widgets/svg_icons.dart';

Color _parseColor(String color) {
  final value = int.tryParse(color.replaceFirst('#', '0xFF'));
  return value != null ? Color(value) : AppColors.accentStart;
}

/// Page for managing categories.
class CategoryManagementPage extends StatelessWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: BlocBuilder<CategoriesBloc, CategoriesState>(
          builder: (context, state) {
            final categories = state is CategoriesLoaded
                ? state.categories
                : <Category>[];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.all(13),
                            child: SvgIcons.chevronLeft(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '分类管理',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 30),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final category = categories[index];
                      return _CategoryListTile(
                        category: category,
                        onEdit: category.isSystem
                            ? null
                            : () => _showEditDialog(context, category),
                        onDelete: category.isSystem
                            ? null
                            : () => _confirmDelete(context, category, categories),
                      );
                    }, childCount: categories.length),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('新增分类'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    _showCategoryDialog(context);
  }

  void _showEditDialog(BuildContext context, Category category) {
    _showCategoryDialog(context, category: category);
  }

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final bloc = context.read<CategoriesBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _CategoryDialog(bloc: bloc, category: category);
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Category category, List<Category> categories) async {
    final replacements = categories.where((item) => item.id != category.id).toList();
    String? replacementId = replacements.isEmpty ? null : replacements.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('删除分类'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('删除“${category.name}”后，关联记录将迁移到替代分类。'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: replacementId,
              decoration: const InputDecoration(labelText: '替代分类'),
              items: replacements.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
              onChanged: (value) => setState(() => replacementId = value),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            TextButton(onPressed: replacementId == null ? null : () => Navigator.pop(dialogContext, true), child: const Text('确认删除')),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CategoriesBloc>().add(CategoryDeleted(category.id, replacementCategoryId: replacementId));
    }
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoriesBloc bloc;
  final Category? category;

  const _CategoryDialog({required this.bloc, this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? '#6366F1';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    return AlertDialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        isEditing ? '编辑分类' : '新增分类',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '分类名称',
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '颜色',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(4),
            child: GestureDetector(
              onTap: () async {
                final picked = await ColorPickerDialog.show(
                  context,
                  initialColor: _selectedColor,
                );
                if (picked != null) {
                  setState(() => _selectedColor = picked);
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _parseColor(_selectedColor),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '取消',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            if (isEditing) {
              widget.bloc.add(
                CategoryUpdated(
                  widget.category!.copyWith(name: name, color: _selectedColor),
                ),
              );
            } else {
              widget.bloc.add(
                CategoryAdded(
                  Category(id: '', name: name, color: _selectedColor),
                ),
              );
            }
            Navigator.pop(context);
          },
          child: const Text(
            '保存',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryListTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryListTile({required this.category, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(category.color.replaceFirst('#', '0xFF'));
    final catColor = value != null ? Color(value) : AppColors.accentStart;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: catColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: category.isSystem
            ? const Text(
                '系统',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
