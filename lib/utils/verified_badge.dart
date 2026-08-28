import 'package:flutter/material.dart';

/// Hardcoded verified emails — add yours here.
const List<String> verifiedEmails = [
  'destinyjob2007@gmail.com', // YOUR EMAIL — add more if needed
];

/// Check if an email is verified.
bool isVerified(String? email) {
  if (email == null || email.isEmpty) return false;
  final clean = email.trim().toLowerCase();
  return verifiedEmails.contains(clean);
}

/// Blue verified tick badge (like Twitter/WhatsApp).
class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool showTooltip;

  const VerifiedBadge({
    super.key,
    this.size = 14,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1DA1F2), // Twitter blue
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        size: size * 0.6,
        color: Colors.white,
        weight: 700,
      ),
    );

    if (showTooltip) {
      return Tooltip(
        message: 'Verified',
        child: badge,
      );
    }
    return badge;
  }
}

/// Shows a username with a blue verified tick if the email is verified.
class VerifiedUsername extends StatelessWidget {
  final String username;
  final String? email;
  final TextStyle? style;
  final double badgeSize;
  final double spacing;
  final int? maxLines;
  final TextOverflow? overflow;

  const VerifiedUsername({
    super.key,
    required this.username,
    this.email,
    this.style,
    this.badgeSize = 14,
    this.spacing = 4,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final isUserVerified = isVerified(email);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            username,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
        if (isUserVerified) ...[
          SizedBox(width: spacing),
          VerifiedBadge(size: badgeSize),
        ],
      ],
    );
  }
}
