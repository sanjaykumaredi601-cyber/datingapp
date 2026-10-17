import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A frosted-glass card using BackdropFilter blur.
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double backgroundOpacity;
  final double borderOpacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.blurSigma = 12.0,
    this.backgroundOpacity = 0.08,
    this.borderOpacity = 0.15,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: backgroundOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Aurora gradient text using ShaderMask.
class AuroraGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final LinearGradient gradient;
  final TextAlign textAlign;

  const AuroraGradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = AppColors.auroraGradient,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style ?? Theme.of(context).textTheme.bodyLarge,
        textAlign: textAlign,
      ),
    );
  }
}

/// Primary CTA button with aurora gradient, loading state and press animation.
class AuroraButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;
  final Widget? icon;

  const AuroraButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.borderRadius = 999,
    this.textStyle,
    this.icon,
  });

  @override
  State<AuroraButton> createState() => _AuroraButtonState();
}

class _AuroraButtonState extends State<AuroraButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isEnabled ? (_) => _controller.forward() : null,
      onTapUp: _isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: _isEnabled ? () => _controller.reverse() : null,
      onTap: _isEnabled ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedOpacity(
          opacity: _isEnabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: widget.width ?? double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: _isEnabled
                  ? AppColors.auroraGradient
                  : const LinearGradient(
                      colors: [AppColors.surfaceL2, AppColors.surfaceL2],
                    ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          widget.icon!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: widget.textStyle ??
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined aurora gradient border button (secondary CTA).
class AuroraOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double borderRadius;

  const AuroraOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 52,
    this.borderRadius = 999,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.auroraGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: const EdgeInsets.all(1.5), // border width
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
          child: Center(
            child: AuroraGradientText(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
