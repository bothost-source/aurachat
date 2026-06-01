import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;
  bool _scrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 50) {
      setState(() => _scrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text('Terms of Service'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.warning.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please read carefully. Violations may result in account restrictions.',
                    style: TextStyle(fontSize: 13, color: AppTheme.warning, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader('TARRIFIC CHAT'),
                  _buildSubHeader('Terms of Service & Community Guidelines'),
                  const SizedBox(height: 8),
                  _buildDate('Last Updated: May 29, 2026'),
                  const SizedBox(height: 24),
                  _buildSection('1. Acceptance of Terms'),
                  _buildParagraph('By accessing or using TARRIFIC CHAT ("the Service"), you agree to be bound by these Terms of Service ("Terms"). If you disagree with any part of the terms, you may not access the Service.'),
                  _buildSection('2. AI-Powered Content Moderation'),
                  _buildParagraph('TARRIFIC CHAT employs advanced artificial intelligence systems to monitor, analyze, and moderate content in real-time. Our AI systems detect and restrict content that violates our Community Guidelines, including:'),
                  _buildBulletPoint('Spam, scams, and fraudulent activities'),
                  _buildBulletPoint('Harassment, hate speech, and bullying'),
                  _buildBulletPoint('Violent content and threats'),
                  _buildBulletPoint('Explicit or adult content'),
                  _buildBulletPoint('Illegal activities and substances'),
                  _buildBulletPoint('Misinformation and disinformation'),
                  _buildBulletPoint('Copyright infringement'),
                  _buildBulletPoint('Phishing and impersonation attempts'),
                  _buildParagraph('By using the Service, you consent to having your messages and content analyzed by our AI moderation systems. Content flagged by AI may be restricted, removed, or reported to authorities as required by law.'),
                  _buildSection('3. Account Restrictions & Enforcement'),
                  _buildParagraph('TARRIFIC CHAT reserves the right to enforce the following actions against accounts that violate these Terms:'),
                  _buildBulletPoint('Warning: Initial notice of violation'),
                  _buildBulletPoint('Content Restriction: Flagged content hidden from other users'),
                  _buildBulletPoint('Temporary Mute: Limited messaging ability for a specified period'),
                  _buildBulletPoint('Account Suspension: Temporary inability to access the Service'),
                  _buildBulletPoint('Permanent Ban: Irreversible termination of account access'),
                  _buildParagraph('Each violation accumulates "strikes" on your account. Three strikes result in automatic account suspension. Severe violations may result in immediate permanent banning without warning.'),
                  _buildSection('4. User Conduct'),
                  _buildParagraph('You agree NOT to use the Service to:'),
                  _buildBulletPoint('Send unsolicited messages (spam) to other users'),
                  _buildBulletPoint('Impersonate any person or entity, including TARRIFIC staff'),
                  _buildBulletPoint('Distribute malware, viruses, or harmful code'),
                  _buildBulletPoint('Collect or harvest user data without consent'),
                  _buildBulletPoint('Circumvent or attempt to bypass AI moderation'),
                  _buildBulletPoint('Create multiple accounts to evade restrictions'),
                  _buildBulletPoint('Use bots or automated systems without authorization'),
                  _buildBulletPoint('Share content that infringes on intellectual property rights'),
                  _buildSection('5. Privacy & Data Protection'),
                  _buildParagraph('Your privacy is important to us. TARRIFIC CHAT collects and processes data in accordance with our Privacy Policy. Key points include:'),
                  _buildBulletPoint('Messages are encrypted in transit using TLS'),
                  _buildBulletPoint('AI analysis is performed on-device and server-side'),
                  _buildBulletPoint('We do not sell your personal data to third parties'),
                  _buildBulletPoint('You can request data deletion at any time'),
                  _buildBulletPoint('Phone numbers can be hidden from other users via privacy settings'),
                  _buildSection('6. Bot Creation & Management'),
                  _buildParagraph('Users may create bots subject to the following conditions:'),
                  _buildBulletPoint('Bots must comply with all Terms and Community Guidelines'),
                  _buildBulletPoint('Bots must not send spam or unsolicited messages'),
                  _buildBulletPoint('Bot creators are responsible for bot behavior'),
                  _buildBulletPoint('TARRIFIC CHAT reserves the right to suspend any bot that violates Terms'),
                  _buildBulletPoint('Bot tokens must be kept secure; compromised tokens must be regenerated immediately'),
                  _buildSection('7. Intellectual Property'),
                  _buildParagraph('TARRIFIC CHAT and its original content, features, and functionality are and will remain the exclusive property of TARRIFIC CHAT and its licensors. The Service is protected by copyright, trademark, and other laws.'),
                  _buildSection('8. Termination'),
                  _buildParagraph('We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms. Upon termination, your right to use the Service will immediately cease.'),
                  _buildSection('9. Limitation of Liability'),
                  _buildParagraph('In no event shall TARRIFIC CHAT, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential or punitive damages.'),
                  _buildSection('10. Changes to Terms'),
                  _buildParagraph('We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will provide notice of any material changes. Your continued use of the Service after any changes constitutes acceptance of the new Terms.'),
                  _buildSection('11. Contact Us'),
                  _buildParagraph('If you have any questions about these Terms, please contact us at:'),
                  _buildBulletPoint('Email: supportaurachat@gmail.com'),
                  _buildBulletPoint('Support: supportaurachat@gmail.com'),
                  _buildBulletPoint('Address: TARRIFIC HQ, Lagos, Nigeria'),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'By tapping "I Agree", you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (!_scrolledToBottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward, size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 6),
                          Text('Scroll to read all terms', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Checkbox(
                        value: _accepted,
                        onChanged: _scrolledToBottom ? (v) => setState(() => _accepted = v ?? false) : null,
                        activeColor: AppTheme.primaryGreen,
                      ),
                      Expanded(
                        child: Text(
                          'I have read and agree to the Terms of Service',
                          style: TextStyle(fontSize: 13, color: _scrolledToBottom ? AppTheme.textPrimary : AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _accepted ? () => Navigator.pushReplacementNamed(context, '/login') : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.bgElevated,
                        disabledForegroundColor: AppTheme.textTertiary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('I Agree & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) => Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, letterSpacing: 2));
  Widget _buildSubHeader(String text) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textSecondary));
  Widget _buildDate(String text) => Text(text, style: TextStyle(fontSize: 12, color: AppTheme.textMuted));
  Widget _buildSection(String text) => Padding(padding: const EdgeInsets.only(top: 24, bottom: 8), child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)));
  Widget _buildParagraph(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)));
  Widget _buildBulletPoint(String text) => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(margin: const EdgeInsets.only(top: 8), width: 5, height: 5, decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5))),
    ]),
  );
}
