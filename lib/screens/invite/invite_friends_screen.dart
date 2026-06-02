import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Invite Friends'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share,
              size: 80,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Invite Friends',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Share TARRIFIC CHAT with your friends',
              style: TextStyle(color: Colors.grey.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Share.share('Join me on TARRIFIC CHAT! Download the app now.');
              },
              child: const Text('Share Invite Link'),
            ),
          ],
        ),
      ),
    );
  }
}
