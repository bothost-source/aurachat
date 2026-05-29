import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  int _filterIndex = 0;
  final _filters = ['All', 'Chats', 'Media', 'Links', 'Files', 'Music', 'Voice'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 18, color: AppTheme.textTertiary), onPressed: () => _controller.clear())
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(_filters[index]),
                  selected: _filterIndex == index,
                  onSelected: (selected) => setState(() => _filterIndex = index),
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: _filterIndex == index ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    fontWeight: _filterIndex == index ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('Search messages, users, and media', style: TextStyle(color: AppTheme.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
