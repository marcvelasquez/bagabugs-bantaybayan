import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/theme/theme_provider.dart';
import '../widgets/checklist_item.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({Key? key}) : super(key: key);

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final Map<String, Map<String, bool>> _checklistCategories = {
    'Water & Food': {
      'Drinking water (3-day supply)': false,
      'Non-perishable food': false,
      'Manual can opener': false,
    },
    'Medical': {
      'First aid kit': false,
      'Prescription medications': false,
      'Medical supplies': false,
    },
    'Tools & Supplies': {
      'Flashlight with batteries': false,
      'Battery-powered radio': false,
      'Multi-tool/Swiss knife': false,
      'Emergency whistle': false,
      'Waterproof matches': false,
    },
    'Documents': {
      'Cash and important documents': false,
      'Copies of ID and insurance': false,
      'Local maps': false,
    },
    'Communication': {
      'Fully charged phone': false,
      'Emergency contact list': false,
    },
    'Personal': {
      'Change of clothes': false,
      'Sleeping bag/blanket': false,
      'Personal hygiene items': false,
    },
    'Special Needs': {
      'Infant supplies (if applicable)': false,
      'Pet supplies (if applicable)': false,
    },
  };

  int _selectedTabIndex = 0;
  final TextEditingController _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  int get _checkedCount {
    int count = 0;
    _checklistCategories.forEach((category, items) {
      count += items.values.where((v) => v).length;
    });
    return count;
  }

  int get _totalCount {
    int count = 0;
    _checklistCategories.forEach((category, items) {
      count += items.length;
    });
    return count;
  }

  double get _progress => _totalCount > 0 ? _checkedCount / _totalCount : 0.0;

  bool _isCategoryComplete(String category) {
    final items = _checklistCategories[category]!;
    return items.values.every((v) => v);
  }

  int _getCategoryCheckedCount(String category) {
    final items = _checklistCategories[category]!;
    return items.values.where((v) => v).length;
  }

  int _getCategoryTotalCount(String category) {
    return _checklistCategories[category]!.length;
  }

  void _toggleItem(String category, String key) {
    setState(() {
      _checklistCategories[category]![key] =
          !_checklistCategories[category]![key]!;
    });
  }

  void _showAddItemDialog() {
    if (_selectedTabIndex == 0) return;

    final category = _checklistCategories.keys.elementAt(_selectedTabIndex - 1);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDarkMode
            ? AppColors.darkBackgroundElevated
            : AppColors.lightBackgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Item to $category',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newItemController,
                autofocus: true,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: isDarkMode ? AppColors.darkTextPrimary : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter item name...',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : Colors.grey[500],
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? AppColors.darkBackgroundDeep
                      : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onSubmitted: (_) {
                  if (_newItemController.text.trim().isNotEmpty) {
                    setState(() {
                      _checklistCategories[category]![_newItemController.text
                          .trim()] = false;
                    });
                    _newItemController.clear();
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _newItemController.clear();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                            color: isDarkMode
                                ? AppColors.darkBorder
                                : Colors.grey[300]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_newItemController.text.trim().isNotEmpty) {
                          setState(() {
                            _checklistCategories[category]![_newItemController
                                .text
                                .trim()] = false;
                          });
                          _newItemController.clear();
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackgroundDeep
          : AppColors.lightBackgroundPrimary,
      appBar: AppBar(
        title: Text(
          'Emergency Checklist',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: isDarkMode ? AppColors.darkTextPrimary : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode
            ? AppColors.darkBackgroundElevated
            : AppColors.lightBackgroundSecondary,
        foregroundColor: isDarkMode ? AppColors.darkTextPrimary : Colors.black87,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Preparedness Progress',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? AppColors.darkTextPrimary
                                : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '$_checkedCount/$_totalCount',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _progress == 1.0
                              ? AppColors.success
                              : const Color(0xFFFF6E40),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: isDarkMode
                          ? AppColors.darkBorder
                          : AppColors.lightBorderPrimary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progress == 1.0
                            ? AppColors.success
                            : const Color(0xFFFF6E40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _checklistCategories.keys.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedTabIndex == 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.black87)
                                : (isDarkMode
                                    ? AppColors.darkBackgroundElevated
                                    : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isDarkMode
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey[700]),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'All',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDarkMode
                                          ? AppColors.darkTextSecondary
                                          : Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final category =
                      _checklistCategories.keys.elementAt(index - 1);
                  final isSelected = _selectedTabIndex == index;
                  final isComplete = _isCategoryComplete(category);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isComplete
                                  ? AppColors.success
                                  : (isDarkMode
                                      ? const Color(0xFFFF6B6B)
                                      : Colors.black87))
                              : (isComplete
                                  ? AppColors.success.withOpacity(0.1)
                                  : (isDarkMode
                                      ? AppColors.darkBackgroundElevated
                                      : Colors.grey[100])),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isComplete && !isSelected
                                ? AppColors.success
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isComplete)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.success,
                                ),
                              ),
                            Text(
                              category,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isComplete
                                        ? AppColors.success
                                        : (isDarkMode
                                            ? AppColors.darkTextSecondary
                                            : Colors.grey[700])),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _selectedTabIndex == 0
                        ? 'All Items'
                        : _checklistCategories.keys
                            .elementAt(_selectedTabIndex - 1),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? AppColors.darkTextPrimary
                          : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedTabIndex > 0)
                    IconButton(
                      onPressed: _showAddItemDialog,
                      icon: const Icon(Icons.add_circle_outline),
                      color: isDarkMode
                          ? AppColors.darkTextPrimary
                          : Colors.black87,
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_selectedTabIndex > 0) const SizedBox(width: 8),
                  Text(
                    _selectedTabIndex == 0
                        ? '$_checkedCount/$_totalCount'
                        : '${_getCategoryCheckedCount(_checklistCategories.keys.elementAt(_selectedTabIndex - 1))}/${_getCategoryTotalCount(_checklistCategories.keys.elementAt(_selectedTabIndex - 1))}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedTabIndex > 0 &&
                              _isCategoryComplete(_checklistCategories.keys
                                  .elementAt(_selectedTabIndex - 1))
                          ? AppColors.success
                          : (isDarkMode
                              ? AppColors.darkTextSecondary
                              : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                children: _selectedTabIndex == 0
                    ? _checklistCategories.entries.expand((categoryEntry) {
                        return categoryEntry.value.entries.map((itemEntry) {
                          return ChecklistItem(
                            title: itemEntry.key,
                            isChecked: itemEntry.value,
                            onTap: () =>
                                _toggleItem(categoryEntry.key, itemEntry.key),
                            onDelete: () {
                              setState(() {
                                _checklistCategories[categoryEntry.key]!
                                    .remove(itemEntry.key);
                              });
                            },
                            isDarkMode: isDarkMode,
                          );
                        });
                      }).toList()
                    : _checklistCategories[_checklistCategories.keys
                            .elementAt(_selectedTabIndex - 1)]!
                        .entries
                        .map((entry) {
                        final category = _checklistCategories.keys
                            .elementAt(_selectedTabIndex - 1);
                        return ChecklistItem(
                          title: entry.key,
                          isChecked: entry.value,
                          onTap: () => _toggleItem(category, entry.key),
                          onDelete: () {
                            setState(() {
                              _checklistCategories[category]!
                                  .remove(entry.key);
                            });
                          },
                          isDarkMode: isDarkMode,
                        );
                      }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
