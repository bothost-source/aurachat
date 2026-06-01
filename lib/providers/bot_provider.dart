import 'package:flutter/foundation.dart';
import '../models/bot_model.dart';

class BotProvider extends ChangeNotifier {
  List<BotModel> _myBots = [];
  List<BotModel> _publicBots = [];
  bool _isLoading = false;

  List<BotModel> get myBots => _myBots;
  List<BotModel> get publicBots => _publicBots;
  bool get isLoading => _isLoading;

  BotProvider() {
    _loadMockBots();
  }

  void _loadMockBots() {
    final now = DateTime.now();
    _myBots = [
      BotModel(
        botId: 'bot_1',
        name: 'TARRIFIC Assistant',
        username: 'tarrific_assistant_bot',
        description: 'Your personal AI assistant for AURACHAT',
        about: 'I can help you with messages, reminders, and business tasks.',
        commands: ['/start', '/help', '/remind', '/translate', '/summarize'],
        commandDescriptions: {
          '/start': 'Start the bot',
          '/help': 'Get help',
          '/remind': 'Set a reminder',
          '/translate': 'Translate text',
          '/summarize': 'Summarize messages',
        },
        status: BotStatus.active,
        ownerId: 'me',
        capabilities: [BotCapability.messaging, BotCapability.inline, BotCapability.customKeyboard],
        inlineMode: true,
        subscriberCount: 3420,
        messageCount: 156780,
        createdAt: now.subtract(const Duration(days: 60)),
        lastActivity: now.subtract(const Duration(minutes: 5)),
        aiPowered: true,
        aiModel: 'GPT-4o',
        autoReply: true,
        autoReplyKeywords: ['help', 'support', 'question'],
        moderationEnabled: true,
      ),
    ];

    _publicBots = [
      BotModel(
        botId: 'bot_pub_1',
        name: 'Crypto Alert Bot',
        username: 'crypto_alert_bot',
        description: 'Real-time cryptocurrency price alerts',
        status: BotStatus.active,
        ownerId: 'user_crypto',
        subscriberCount: 50000,
        messageCount: 2000000,
        createdAt: now.subtract(const Duration(days: 200)),
        lastActivity: now.subtract(const Duration(minutes: 1)),
      ),
      BotModel(
        botId: 'bot_pub_2',
        name: 'Weather Bot',
        username: 'weather_now_bot',
        description: 'Get weather updates for any location',
        status: BotStatus.active,
        ownerId: 'user_weather',
        subscriberCount: 120000,
        messageCount: 5000000,
        createdAt: now.subtract(const Duration(days: 300)),
        lastActivity: now.subtract(const Duration(minutes: 2)),
      ),
    ];

    notifyListeners();
  }

  Future<void> createBot({
    required String name,
    required String username,
    String? description,
    String? about,
    bool aiPowered = false,
    String? aiModel,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    final bot = BotModel(
      botId: 'bot_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      username: username,
      description: description,
      about: about,
      status: BotStatus.pending,
      ownerId: 'me',
      createdAt: DateTime.now(),
      aiPowered: aiPowered,
      aiModel: aiModel,
    );

    _myBots.add(bot);
    _isLoading = false;
    notifyListeners();
  }

  void updateBot(String botId, BotModel updatedBot) {
    final index = _myBots.indexWhere((b) => b.botId == botId);
    if (index != -1) {
      _myBots[index] = updatedBot;
      notifyListeners();
    }
  }

  void deleteBot(String botId) {
    _myBots.removeWhere((b) => b.botId == botId);
    notifyListeners();
  }

  void regenerateToken(String botId) {
    final index = _myBots.indexWhere((b) => b.botId == botId);
    if (index != -1) {
      final newToken = 'bot${_generateToken()}';
      _myBots[index] = _myBots[index].copyWith(token: newToken);
      notifyListeners();
    }
  }

  String _generateToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000000 + (DateTime.now().microsecond % 9000000)).toString();
  }
}
