import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/moderation_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ViolationType? _selectedViolation;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _violationTypes = [
    {'type': ViolationType.spam, 'label': 'Spam', 'icon': Icons.block, 'color': AppTheme.warning},
    {'type': ViolationType.harassment, 'label': 'Harassment', 'icon': Icons.sentiment_very_dissatisfied, 'color': AppTheme.error},
    {'type': ViolationType.hateSpeech, 'label': 'Hate Speech', 'icon': Icons.record_voice_over, 'color': AppTheme.error},
    {'type': ViolationType.violence, 'label': 'Violence', 'icon': Icons.warning, 'color': AppTheme.error},
    {'type': ViolationType.explicit, 'label': 'Explicit Content', 'icon': Icons.no_adult_content, 'color': AppTheme.accentPink},
    {'type': ViolationType.illegal, 'label': 'Illegal Activity', 'icon': Icons.gavel, 'color': AppTheme.error},
    {'type': ViolationType.misinformation, 'label': 'Misinformation', 'icon': Icons.info, 'color': AppTheme.warning},
    {'type': ViolationType.phishing, 'label': 'Phishing', 'icon': Icons.phishing, 'color': AppTheme.error},
    {'type': ViolationType.impersonation, 'label': 'Impersonation', 'icon': Icons.person_off, 'color': AppTheme.warning},
    {'type': ViolationType.copyright, 'label': 'Copyright', 'icon': Icons.copyright, 'color': AppTheme.accentBlue},
  ];

  void _submitReport() async {
    if (_selectedViolation == null || _descriptionController.text.isEmpty) return;
    setState(() => _isSubmitting = true);
    await context.read<ModerationProvider>().submitReport(
      reporterId: 'me',
      violationType: _selectedViolation!,
      description: _descriptionController.text,
    );
    setState(() => _isSubmitting = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Our team will review it.'), backgroundColor: AppTheme.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text('Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield, color: AppTheme.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reports are reviewed by our AI moderation system and human moderators. False reports may result in account action.',
                      style: TextStyle(fontSize: 13, color: AppTheme.error.withOpacity(0.8), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('What are you reporting?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _violationTypes.map((v) => ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(v['icon'], size: 14, color: _selectedViolation == v['type'] ? v['color'] : AppTheme.textTertiary),
                    const SizedBox(width: 6),
                    Text(v['label']),
                  ],
                ),
                selected: _selectedViolation == v['type'],
                onSelected: (selected) {
                  setState(() => _selectedViolation = selected ? v['type'] : null);
                },
                selectedColor: (v['color'] as Color).withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _selectedViolation == v['type'] ? v['color'] : AppTheme.textSecondary,
                  fontWeight: _selectedViolation == v['type'] ? FontWeight.w600 : FontWeight.normal,
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Please provide details about the violation...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.bgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Include message IDs, usernames, or screenshots if available.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.bgElevated,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
