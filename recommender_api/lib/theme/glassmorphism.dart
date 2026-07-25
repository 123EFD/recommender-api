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
        ? Colors.white.withValues(alpha: opacity) 
        : Colors.white.withValues(alpha: opacity * 0.6);
    final fillBottomRight = isLight 
        ? Colors.white.withValues(alpha: opacity * 0.4) 
        : Colors.white.withValues(alpha: opacity * 0.2);
    final borderCol = Colors.white.withValues(alpha: borderOpacity);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderCol),
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
