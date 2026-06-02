import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to TARRIFIC CHAT',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'By using this app, you agree to our Terms of Service and Privacy Policy.\n\n'
              '1. You must be at least 13 years old to use this app.\n'
              '2. You are responsible for your account security.\n'
              '3. Do not share illegal or harmful content.\n'
              '4. We reserve the right to terminate accounts that violate our policies.\n\n'
              'For more information, contact supportaurachat@gmail.com.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('I Agree'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
