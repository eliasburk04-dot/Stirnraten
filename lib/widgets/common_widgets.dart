import 'package:flutter/material.dart';

import '../models/player.dart';

/// Player avatar widget with initials
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double radius;
  final bool showBadge;
  final String? badgeText;
  final Color? badgeColor;

  const PlayerAvatar({
    super.key,
    required this.player,
    this.radius = 24,
    this.showBadge = false,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: player.avatarColor,
          child: Text(
            player.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.6,
            ),
          ),
        ),
        if (showBadge && badgeText != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Animated loading indicator with custom message
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom action button with loading state
class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isOutlined;

  const ActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isOutlined
        ? OutlinedButton.styleFrom(
            side: BorderSide(
              color: backgroundColor ?? Theme.of(context).colorScheme.primary,
            ),
            foregroundColor:
                foregroundColor ?? Theme.of(context).colorScheme.primary,
          )
        : ElevatedButton.styleFrom(
            backgroundColor:
                backgroundColor ?? Theme.of(context).colorScheme.primary,
            foregroundColor: foregroundColor ?? Colors.white,
          );

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                foregroundColor ?? Colors.white,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: style,
              child: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: style,
              child: child,
            ),
    );
  }
}

/// Status chip for showing player states
class StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? activeColor;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive 
        ? (activeColor ?? Colors.green) 
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient background container
class GradientBackground extends StatelessWidget {
  final Widget child;
  
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          ],
        ),
      ),
      child: child,
    );
  }
}
