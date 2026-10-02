import 'package:flutter/material.dart';
import '../models/category.dart';
import '../screens/home/home_colors.dart';
import '../screens/home/home_icons.dart';

/// Bottom Sheet lọc giao dịch theo danh mục với giao diện hiện đại,
/// hỗ trợ tìm kiếm nhanh không dấu và phân loại tab thông minh.
class TransactionCategoryFilterSheet extends StatefulWidget {
  final List<Category> categories;
  final int? selectedCategoryId;

  const TransactionCategoryFilterSheet({
    super.key,
    required this.categories,
    this.selectedCategoryId,
  });

  @override
  State<TransactionCategoryFilterSheet> createState() =>
      _TransactionCategoryFilterSheetState();
}

class _TransactionCategoryFilterSheetState
    extends State<TransactionCategoryFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  String _selectedType = 'all'; // 'all', 'expense', 'income'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchKeyword = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _removeVietnameseDiacritics(String str) {
    const withDiacritics =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỬÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioooooooooooooooooouuuuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOOOUUUUUUUUUUUUUYYYYYD';

    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  List<Category> get _filteredCategories {
    return widget.categories.where((category) {
      // Lọc theo loại chi tiêu / thu nhập
      if (_selectedType != 'all' && category.type != _selectedType) {
        return false;
      }

      // Lọc theo từ khóa tìm kiếm (hỗ trợ tiếng Việt không dấu)
      if (_searchKeyword.isNotEmpty) {
        final normalizedName =
            _removeVietnameseDiacritics(category.name.toLowerCase());
        final normalizedKeyword =
            _removeVietnameseDiacritics(_searchKeyword.toLowerCase());
        if (!normalizedName.contains(normalizedKeyword)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final allCategories = widget.categories;
    final expenseCount = allCategories.where((c) => c.type == 'expense').length;
    final incomeCount = allCategories.where((c) => c.type == 'income').length;
    final filteredList = _filteredCategories;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lọc theo danh mục',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (widget.selectedCategoryId != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context, -1); // -1 nghĩa là reset về All
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Xóa lọc'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm danh mục nhanh...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Type Filter Chips / Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTypeChip(
                  type: 'all',
                  label: 'Tất cả (${allCategories.length})',
                  icon: Icons.apps_rounded,
                  activeColor: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  type: 'expense',
                  label: 'Chi tiêu ($expenseCount)',
                  icon: Icons.arrow_downward_rounded,
                  activeColor: HomeColors.expense,
                ),
                const SizedBox(width: 8),
                _buildTypeChip(
                  type: 'income',
                  label: 'Thu nhập ($incomeCount)',
                  icon: Icons.arrow_upward_rounded,
                  activeColor: HomeColors.income,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),

          // Categories Grid / List Area
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchKeyword.isNotEmpty
                                ? 'Không tìm thấy danh mục "$_searchKeyword"'
                                : 'Chưa có danh mục nào',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Option "Tất cả danh mục" (chỉ hiện khi đang xem tab Tất cả hoặc khi không search)
                        if (_selectedType == 'all' && _searchKeyword.isEmpty) ...[
                          _buildAllCategoriesOption(context),
                          const SizedBox(height: 14),
                        ],

                        // Grid 3 cột cho các danh mục
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final category = filteredList[index];
                            final isSelected =
                                widget.selectedCategoryId == category.id;
                            final isIncome = category.type == 'income';
                            final typeColor =
                                isIncome ? HomeColors.income : HomeColors.expense;

                            return InkWell(
                              onTap: () {
                                Navigator.pop(context, category.id);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? typeColor.withValues(alpha: 0.12)
                                      : Colors.transparent, // Trùng với màu nền
                                  borderRadius: BorderRadius.circular(16),
                                  border: isSelected
                                      ? Border.all(color: typeColor, width: 2)
                                      : null, // Không có border bao quanh ở trạng thái bình thường
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: HomeColors.getTransactionIconBackground(typeColor),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  HomeIcons.getIconFromString(category.icon),
                                                  color: typeColor,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              category.name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? typeColor
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: typeColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String type,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : colorScheme.outline.withValues(alpha: 0.15),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? activeColor : colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllCategoriesOption(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = widget.selectedCategoryId == null;

    return InkWell(
      onTap: () {
        Navigator.pop(context, -1); // Chọn tất cả danh mục
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent, // Trùng với màu nền
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.category_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tất cả danh mục',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Hiển thị tất cả giao dịch thu & chi',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
