import 'package:flutter/material.dart';

/// Hardcoded verified phone numbers — add yours here.
/// Format: digits only, no '+' or spaces.
const List<String> verifiedNumbers = [
  '2349135204957', // YOUR NUMBER — add more if needed
];

/// Check if a phone number is verified.
bool isVerified(String? phoneNumber) {
  if (phoneNumber == null || phoneNumber.isEmpty) return false;
  final clean = phoneNumber.replaceAll('+', '').replaceAll(' ', '').trim();
  return verifiedNumbers.contains(clean);
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

/// Shows a username with a blue verified tick if the phone number is verified.
class VerifiedUsername extends StatelessWidget {
  final String username;
  final String? phoneNumber;
  final TextStyle? style;
  final double badgeSize;
  final double spacing;
  final int? maxLines;
  final TextOverflow? overflow;

  const VerifiedUsername({
    super.key,
    required this.username,
    this.phoneNumber,
    this.style,
    this.badgeSize = 14,
    this.spacing = 4,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final isUserVerified = isVerified(phoneNumber);

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
