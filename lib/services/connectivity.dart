import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../themes/app_theme.dart';

// ============================================================================
// CONNECTIVITY SERVICE — Singleton that monitors network state
// ============================================================================
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _controller = StreamController<NetworkState>.broadcast();

  Stream<NetworkState> get stateStream => _controller.stream;
  NetworkState _currentState = NetworkState.unknown;
  NetworkState get currentState => _currentState;

  Timer? _pingTimer;
  bool _isDisposed = false;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((results) async {
      if (_isDisposed) return;

  bool hasConnection = false;
  for (final r in results) {
    if (r == ConnectivityResult.wifi || r == ConnectivityResult.mobile || r == ConnectivityResult.ethernet) {
       hasConnection = true;
       break;
      }
     }

      if (hasConnection) {
        // Don't immediately say online — verify with actual ping
        _setState(NetworkState.connecting);
        await _verifyConnection();
      } else {
        _setState(NetworkState.offline);
      }
    });

    // Periodic ping to detect "connected but no internet" (captive portals, etc.)
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isDisposed) return;
      if (_currentState == NetworkState.online || _currentState == NetworkState.connecting) {
        await _verifyConnection();
      }
    });
  }

  Future<void> _verifyConnection() async {
    try {
      // Ping a reliable endpoint — replace with your backend URL
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _setState(NetworkState.online);
      } else {
        _setState(NetworkState.connecting); // DNS resolved but no route
      }
    } on SocketException catch (_) {
      _setState(NetworkState.offline);
    } on TimeoutException catch (_) {
      _setState(NetworkState.connecting); // Slow/unstable — show connecting
    } catch (_) {
      _setState(NetworkState.connecting);
    }
  }

  void _setState(NetworkState state) {
    if (_currentState != state) {
      _currentState = state;
      _controller.add(state);
    }
  }

  Future<bool> checkNow() async {
    _setState(NetworkState.connecting);
    await _verifyConnection();
    return _currentState == NetworkState.online;
  }

  void dispose() {
    _isDisposed = true;
    _pingTimer?.cancel();
    _controller.close();
  }
}

enum NetworkState { unknown, online, offline, connecting }

// ============================================================================
// CONNECTIVITY WRAPPER — Wraps your entire app or specific screens
// ============================================================================
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool showBanner; // Show "Connecting..." banner at top
  final bool blockWhenOffline; // Show full offline screen
  final VoidCallback? onBackOnline;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showBanner = true,
    this.blockWhenOffline = false,
    this.onBackOnline,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  NetworkState _state = NetworkState.unknown;
  late StreamSubscription<NetworkState> _sub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    final service = ConnectivityService();
    service.initialize();
    _state = service.currentState;

    _sub = service.stateStream.listen((state) {
      if (mounted) {
        setState(() => _state = state);
        if (state == NetworkState.online && widget.onBackOnline != null) {
          widget.onBackOnline!();
        }
      }
    });

    // Initial check
    service.checkNow();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Banner at top
        if (widget.showBanner && _state != NetworkState.online)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildStatusBanner(),
          ),

        // Full offline blocker
        if (widget.blockWhenOffline && _state == NetworkState.offline)
          _buildOfflineScreen(),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final isConnecting = _state == NetworkState.connecting || _state == NetworkState.unknown;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 36,
      color: isConnecting ? Colors.orange.shade700 : Colors.red.shade700,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnecting) ...[
                // Pulsing dots
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(0),
                        _buildDot(1),
                        _buildDot(2),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(Icons.wifi_off, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                isConnecting ? 'Connecting...' : 'No internet connection',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              if (!isConnecting) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ConnectivityService().checkNow(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final delay = index * 0.3;
    final value = (_pulseController.value + delay) % 1.0;
    final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3 + (opacity * 0.7)),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildOfflineScreen() {
    return Container(
      color: AppTheme.bgPrimary,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.signal_wifi_off,
                size: 80,
                color: AppTheme.textTertiary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Check your connection and try again',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => ConnectivityService().checkNow(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Allow user to view cached content offline
                  // You handle this in your state management
                },
                child: const Text(
                  'View Offline Content',
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// OFFLINE-AWARE BUTTON — Disables when offline, shows tooltip
// ============================================================================
class OfflineAwareButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String offlineTooltip;

  const OfflineAwareButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.offlineTooltip = 'No internet connection',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: ConnectivityService().stateStream,
      initialData: ConnectivityService().currentState,
      builder: (context, snapshot) {
        final isOnline = snapshot.data == NetworkState.online;

        return Tooltip(
          message: isOnline ? '' : offlineTooltip,
          child: IgnorePointer(
            ignoring: !isOnline,
            child: Opacity(
              opacity: isOnline ? 1.0 : 0.4,
              child: GestureDetector(
                onTap: isOnline ? onPressed : () {
                  _showOfflineSnack(context);
                },
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOfflineSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Waiting for network...'),
            const Spacer(),
            TextButton(
              onPressed: () => ConnectivityService().checkNow(),
              child: const Text('RETRY', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// NETWORK-AWARE IMAGE — Shows placeholder when offline
// ============================================================================
class NetworkAwareImage extends StatelessWidget {
  final String imageUrl;
  final String? localPath;
  final Widget placeholder;
  final BoxFit fit;

  const NetworkAwareImage({
    super.key,
    required this.imageUrl,
    this.localPath,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: ConnectivityService().stateStream,
      initialData: ConnectivityService().currentState,
      builder: (context, snapshot) {
        final isOnline = snapshot.data == NetworkState.online;

        if (localPath != null && File(localPath!).existsSync()) {
          return Image.file(File(localPath!), fit: fit);
        }

        if (!isOnline) {
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, color: Colors.white70, size: 32),
                      SizedBox(height: 4),
                      Text(
                        'Offline',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Image.network(
          imageUrl,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder;
          },
          errorBuilder: (context, error, stack) => placeholder,
        );
      },
    );
  }
}

// ============================================================================
// USAGE: Wrap your main app in ConnectivityWrapper
// ============================================================================
// In main.dart:
// 
// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   ConnectivityService().initialize();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: ConnectivityWrapper(
//         showBanner: true,
//         blockWhenOffline: false, // Set true for full blocker
//         child: HomeScreen(),
//       ),
//     );
//   }
// }
//
// For specific screens (like chat):
// FloatingActionButton(
//   onPressed: () => sendMessage(),
//   child: OfflineAwareButton(
//     onPressed: () => sendMessage(),
//     child: Icon(Icons.send),
//   ),
// )
