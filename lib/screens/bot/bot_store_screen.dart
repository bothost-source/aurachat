import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/bot_provider.dart';

class BotStoreScreen extends StatelessWidget {
  const BotStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final botProvider = context.watch<BotProvider>();
    final myBots = botProvider.myBots;
    final publicBots = botProvider.publicBots;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppTheme.bgSecondary,
          elevation: 0,
          title: const Text('Bot Store'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Discover'),
              Tab(text: 'My Bots'),
              Tab(text: 'Create'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: AppTheme.textPrimary),
              onPressed: () {},
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Discover Tab
            _buildDiscoverTab(publicBots),
            // My Bots Tab
            _buildMyBotsTab(myBots),
            // Create Tab
            _buildCreateTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTab(List bots) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Featured Banner
        Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('FEATURED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Create AI-Powered Bots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Build smart assistants with GPT-4o integration', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Popular Bots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...bots.map((bot) => _buildBotCard(bot, isPublic: true)),
      ],
    );
  }

  Widget _buildMyBotsTab(List bots) {
    if (bots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text('No bots yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Create your first bot to get started', style: TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: bots.map((bot) => _buildBotCard(bot, isPublic: false)).toList(),
    );
  }

  Widget _buildCreateTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                    SizedBox(width: 10),
                    Text('Bot Creation Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRule('Bots must comply with Terms of Service'),
                _buildRule('No spam or unsolicited messaging'),
                _buildRule('Bot creator is responsible for bot behavior'),
                _buildRule('AI-powered bots are moderated automatically'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/bot_creator'),
              icon: const Icon(Icons.add),
              label: const Text('Create New Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildBotCard(dynamic bot, {required bool isPublic}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Icon(Icons.smart_toy, color: Colors.white, size: 28)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bot.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('@${bot.username}', style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen)),
                const SizedBox(height: 4),
                Text(
                  bot.description ?? 'No description',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text('${bot.subscriberCount} subscribers', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                    const SizedBox(width: 16),
                    Icon(Icons.message, size: 14, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text('${bot.messageCount} messages', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
          if (!isPublic)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textTertiary),
              color: AppTheme.bgModal,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuItem(value: 'token', child: Text('Regenerate Token', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuItem(value: 'analytics', child: Text('Analytics', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.error))),
              ],
            ),
        ],
      ),
    );
  }
}
