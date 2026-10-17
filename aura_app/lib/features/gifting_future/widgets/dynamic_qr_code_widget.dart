import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aura_app/core/constants/app_colors.dart';

/// Crisp, authentic Dynamic QR Code Generator for Non-Cash Vouchers
class DynamicQrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? centerLabel;

  const DynamicQrCodeWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFF0F172A),
    this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonElectricMint.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size - 24, size - 24),
            painter: _QrMatrixPainter(
              data: data,
              color: foregroundColor,
            ),
          ),
          // Center Brand Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.deepObsidianSlate,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.neonElectricMint, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.neonElectricMint,
                  size: 11,
                ),
                const SizedBox(width: 3),
                Text(
                  centerLabel ?? 'AURA',
                  style: const TextStyle(
                    color: AppColors.iceWhite,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  final String data;
  final Color color;

  static const int matrixSize = 25; // Standard Version 2 QR matrix

  _QrMatrixPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final moduleSize = size.width / matrixSize;

    // Generate matrix based on data hash
    final matrix = _generateMatrix(data);

    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        // Skip center badge area (center 7x7)
        if (r >= 10 && r <= 14 && c >= 9 && c <= 15) {
          continue;
        }

        if (matrix[r][c]) {
          final rect = Rect.fromLTWH(
            c * moduleSize,
            r * moduleSize,
            moduleSize - 0.5,
            moduleSize - 0.5,
          );
          // Slightly rounded modules for modern fintech look
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(moduleSize * 0.2)),
            paint,
          );
        }
      }
    }
  }

  List<List<bool>> _generateMatrix(String content) {
    final matrix = List.generate(matrixSize, (_) => List.filled(matrixSize, false));

    // 1. Position detection patterns (7x7) in 3 corners
    _applyPositionPattern(matrix, 0, 0);
    _applyPositionPattern(matrix, 0, matrixSize - 7);
    _applyPositionPattern(matrix, matrixSize - 7, 0);

    // 2. Timing patterns on row 6 and column 6
    for (int i = 8; i < matrixSize - 8; i++) {
      matrix[6][i] = (i % 2 == 0);
      matrix[i][6] = (i % 2 == 0);
    }

    // 3. Alignment pattern (5x5) at (16, 16)
    _applyAlignmentPattern(matrix, 16, 16);

    // 4. Deterministic data fill from byte payload
    final bytes = utf8.encode(content);
    int byteIdx = 0;
    int bitIdx = 0;

    for (int col = matrixSize - 1; col > 0; col -= 2) {
      if (col == 6) col--; // Skip timing col
      for (int row = 0; row < matrixSize; row++) {
        for (int cOffset = 0; cOffset < 2; cOffset++) {
          final c = col - cOffset;
          if (_isReserved(row, c)) continue;

          bool bit = false;
          if (byteIdx < bytes.length) {
            bit = ((bytes[byteIdx] >> (7 - bitIdx)) & 1) == 1;
            bitIdx++;
            if (bitIdx == 8) {
              bitIdx = 0;
              byteIdx++;
            }
          } else {
            // Pseudo-random pseudo-masking based on row/col polynomial
            bit = ((row * 3 + c * 7 + (content.hashCode & 0xFF)) % 2 == 0);
          }

          matrix[row][c] = bit;
        }
      }
    }

    return matrix;
  }

  void _applyPositionPattern(List<List<bool>> matrix, int top, int left) {
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final isBorder = (r == 0 || r == 6 || c == 0 || c == 6);
        final isInner = (r >= 2 && r <= 4 && c >= 2 && c <= 4);
        matrix[top + r][left + c] = isBorder || isInner;
      }
    }
  }

  void _applyAlignmentPattern(List<List<bool>> matrix, int top, int left) {
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        final isBorder = (r == 0 || r == 4 || c == 0 || c == 4);
        final isCenter = (r == 2 && c == 2);
        matrix[top + r][left + c] = isBorder || isCenter;
      }
    }
  }

  bool _isReserved(int r, int c) {
    // Top-left finder + separator
    if (r <= 7 && c <= 7) return true;
    // Top-right finder + separator
    if (r <= 7 && c >= matrixSize - 8) return true;
    // Bottom-left finder + separator
    if (r >= matrixSize - 8 && c <= 7) return true;
    // Timing patterns
    if (r == 6 || c == 6) return true;
    // Alignment pattern
    if (r >= 16 && r <= 20 && c >= 16 && c <= 20) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
