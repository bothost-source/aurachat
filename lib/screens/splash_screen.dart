import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // FIXED: If this screen is opened directly (not via AuthRouter),
    // it will self-navigate after animation. AuthRouter handles the normal flow.
    _selfNavigateIfNeeded();
  }

  /// FIXED: Safe fallback navigation if splash is opened directly.
  /// Normal flow: AuthRouter shows splash for 2.5s then routes.
  /// Fallback: If splash is still showing after 4s, navigate based on auth state.
  Future<void> _selfNavigateIfNeeded() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted || _hasNavigated) return;

    final prefs = await SharedPreferences.getInstance();
    final mockUserId = prefs.getString('mock_user_id');
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null || mockUserId != null) {
      final userId = currentUser?.uid ?? mockUserId!;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final data = userDoc.data();
        final hasUsername = data?['username'] != null && (data?['username'] as String).trim().isNotEmpty;
        final hasDisplayName = data?['display_name'] != null && (data?['display_name'] as String).trim().isNotEmpty;
        final createdAt = data?['created_at'];
        final hasProfile = userDoc.exists && hasUsername && hasDisplayName && createdAt != null;

        if (hasProfile) {
          Navigator.pushReplacementNamed(context, '/main');
        } else {
          Navigator.pushReplacementNamed(context, '/setup_profile');
        }
      } catch (e) {
        Navigator.pushReplacementNamed(context, '/setup_profile');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
    _hasNavigated = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow effect
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(
                              0.3 * _glowAnimation.value,
                            ),
                            blurRadius: 60 * _glowAnimation.value,
                            spreadRadius: 20 * _glowAnimation.value,
                          ),
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withOpacity(
                              0.2 * _glowAnimation.value,
                            ),
                            blurRadius: 40 * _glowAnimation.value,
                            spreadRadius: 10 * _glowAnimation.value,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // App name with gradient
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6), // Purple
                        Color(0xFF06B6D4), // Cyan
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: const Text(
                      'AURA',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'CHAT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 8,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                // Loading indicator
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF8B5CF6).withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
