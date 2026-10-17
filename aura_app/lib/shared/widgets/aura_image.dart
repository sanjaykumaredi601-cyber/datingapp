import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Versatile image widget that seamlessly displays:
/// 1. Remote HTTP/HTTPS images (with CachedNetworkImage & memory caching)
/// 2. Local device files (from ImagePicker gallery / camera capture)
/// 3. Flutter asset images
/// 4. Graceful fallback placeholder
class AuraImage extends StatelessWidget {
  final String? imageSource;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AuraImage({
    super.key,
    required this.imageSource,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  /// Helper to get an ImageProvider (Network, File, or Asset)
  static ImageProvider provider(String? source, {String fallbackUrl = ''}) {
    final effectiveSource = (source != null && source.isNotEmpty) ? source : fallbackUrl;
    if (effectiveSource.isEmpty) {
      return const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800');
    }
    if (effectiveSource.startsWith('http://') || effectiveSource.startsWith('https://')) {
      return CachedNetworkImageProvider(effectiveSource);
    }
    final file = File(effectiveSource);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return NetworkImage(effectiveSource);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final src = imageSource?.trim();

    if (src == null || src.isEmpty) {
      content = errorWidget ?? _defaultPlaceholder();
    } else if (src.startsWith('http://') || src.startsWith('https://')) {
      content = CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => placeholder ?? _defaultLoading(),
        errorWidget: (context, url, error) => Image.network(
          src,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => errorWidget ?? _defaultPlaceholder(),
        ),
      );
    } else if (src.startsWith('assets/')) {
      content = Image.asset(
        src,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => errorWidget ?? _defaultPlaceholder(),
      );
    } else {
      final file = File(src);
      if (file.existsSync()) {
        content = Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => errorWidget ?? _defaultPlaceholder(),
        );
      } else {
        content = errorWidget ?? _defaultPlaceholder();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _defaultLoading() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceL2,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.sunsetCoral,
          ),
        ),
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceL2,
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }
}
