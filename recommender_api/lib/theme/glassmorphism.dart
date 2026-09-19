import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurAmount;
  final double opacity;
  final double borderOpacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurAmount = 12.0,
    this.opacity = 0.12,
    this.borderOpacity = 0.2,
    this.padding,
    this.margin,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    
    final fillTopLeft = isLight 
        ? const Color(0xFFFAF8F5).withValues(alpha: (opacity * 2.5).clamp(0.0, 0.90)) 
        : const Color(0xFF26292E).withValues(alpha: (opacity * 2.0).clamp(0.0, 0.85));
    final fillBottomRight = isLight 
        ? const Color(0xFFEDE8DC).withValues(alpha: (opacity * 1.8).clamp(0.0, 0.70)) 
        : const Color(0xFF1E2024).withValues(alpha: (opacity * 1.5).clamp(0.0, 0.60));
    final borderCol = isLight
        ? const Color(0xFFD5B893).withValues(alpha: (borderOpacity * 1.8).clamp(0.0, 0.65))
        : const Color(0xFFBFA76F).withValues(alpha: (borderOpacity * 1.2).clamp(0.0, 0.45));

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isLight 
                ? const Color(0xFF4B3B2A).withValues(alpha: 0.05) 
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderCol, width: 1.2),
              gradient: gradient ?? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fillTopLeft,
                  fillBottomRight,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
