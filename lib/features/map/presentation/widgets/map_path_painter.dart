import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MapPathPainter extends CustomPainter {
  const MapPathPainter({
    required this.points,
    this.scrollOffset = 0,
    this.completedSegments = 0,
  });

  final List<Offset> points;
  final double scrollOffset;
  final int completedSegments;

  static const Color _brown = Color(0xFF4E342E);
  static const Color _completedColor = Color(0xFF43A047);
  static const double _strokeWidth = 5;
  static const double _dash = 14;
  static const double _gap = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    // Draw completed path segments (solid green)
    if (completedSegments > 0) {
      final Path completedPath = Path();
      final Offset cFirst = Offset(
        points.first.dx,
        points.first.dy - scrollOffset,
      );
      completedPath.moveTo(cFirst.dx, cFirst.dy);

      final int segCount = math.min(completedSegments, points.length - 1);
      for (int i = 0; i < segCount; i++) {
        final Offset start = Offset(
          points[i].dx,
          points[i].dy - scrollOffset,
        );
        final Offset end = Offset(
          points[i + 1].dx,
          points[i + 1].dy - scrollOffset,
        );
        final Offset control = Offset(
          (start.dx + end.dx) / 2,
          start.dy + ((end.dy - start.dy) * 0.5),
        );
        completedPath.quadraticBezierTo(
          control.dx,
          control.dy,
          end.dx,
          end.dy,
        );
      }

      final Paint completedPaint = Paint()
        ..color = _completedColor
        ..strokeWidth = _strokeWidth + 1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(completedPath, completedPaint);
    }

    // Draw remaining path segments (dashed brown)
    final int startFrom = completedSegments;
    if (startFrom < points.length - 1) {
      final Path remainingPath = Path();
      final Offset rFirst = Offset(
        points[startFrom].dx,
        points[startFrom].dy - scrollOffset,
      );
      remainingPath.moveTo(rFirst.dx, rFirst.dy);

      for (int i = startFrom; i < points.length - 1; i++) {
        final Offset start = Offset(
          points[i].dx,
          points[i].dy - scrollOffset,
        );
        final Offset end = Offset(
          points[i + 1].dx,
          points[i + 1].dy - scrollOffset,
        );
        final Offset control = Offset(
          (start.dx + end.dx) / 2,
          start.dy + ((end.dy - start.dy) * 0.5),
        );
        remainingPath.quadraticBezierTo(
          control.dx,
          control.dy,
          end.dx,
          end.dy,
        );
      }

      final Paint dashPaint = Paint()
        ..color = _brown
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (final ui.PathMetric metric in remainingPath.computeMetrics()) {
        double distance = 0;
        while (distance < metric.length) {
          final double next = math.min(distance + _dash, metric.length);
          final Path segment = metric.extractPath(distance, next);
          canvas.drawPath(segment, dashPaint);
          distance += _dash + _gap;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MapPathPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.completedSegments != completedSegments;
  }
}
