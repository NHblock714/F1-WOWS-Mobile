import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 漂移节点 + 自动连线的星座背景 (与 PC ConstellationBackground 等价).
class ConstellationBackground extends StatefulWidget {
  final Widget? child;
  final int nodeCount;
  final double connectDist;
  final Color color;
  final int pointAlpha;
  final int lineAlpha;

  const ConstellationBackground({
    super.key,
    this.child,
    this.nodeCount = 35,
    this.connectDist = 140,
    this.color = const Color(0xFFFFD700),
    this.pointAlpha = 200,
    this.lineAlpha = 100,
  });

  @override
  State<ConstellationBackground> createState() => _ConstellationBackgroundState();
}

class _ConstellationBackgroundState extends State<ConstellationBackground>
    with SingleTickerProviderStateMixin {
  late final List<_Node> _nodes;
  late final AnimationController _ctrl;
  final _rand = math.Random();
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _nodes = [];
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _initNodes(Size size) {
    _nodes.clear();
    for (int i = 0; i < widget.nodeCount; i++) {
      _nodes.add(_Node(
        x: _rand.nextDouble() * size.width,
        y: _rand.nextDouble() * size.height,
        vx: (_rand.nextDouble() - 0.5) * 0.7,
        vy: (_rand.nextDouble() - 0.5) * 0.6,
      ));
    }
  }

  void _tick(Size size) {
    if (size != _lastSize) {
      _initNodes(size);
      _lastSize = size;
      return;
    }
    for (final n in _nodes) {
      n.x += n.vx;
      n.y += n.vy;
      if (n.x < 0) { n.x = 0; n.vx = -n.vx; }
      if (n.x > size.width) { n.x = size.width; n.vx = -n.vx; }
      if (n.y < 0) { n.y = 0; n.vy = -n.vy; }
      if (n.y > size.height) { n.y = size.height; n.vy = -n.vy; }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _tick(Size(c.maxWidth, c.maxHeight));
      return Stack(children: [
        Positioned.fill(child: CustomPaint(
          painter: _ConstellationPainter(
            nodes: _nodes,
            connectDist: widget.connectDist,
            color: widget.color,
            pointAlpha: widget.pointAlpha,
            lineAlpha: widget.lineAlpha,
          ),
        )),
        if (widget.child != null) widget.child!,
      ]);
    });
  }
}

class _Node {
  double x, y, vx, vy;
  _Node({required this.x, required this.y, required this.vx, required this.vy});
}

class _ConstellationPainter extends CustomPainter {
  final List<_Node> nodes;
  final double connectDist;
  final Color color;
  final int pointAlpha;
  final int lineAlpha;
  _ConstellationPainter({
    required this.nodes,
    required this.connectDist,
    required this.color,
    required this.pointAlpha,
    required this.lineAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final d2max = connectDist * connectDist;
    // lines
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        final d2 = dx * dx + dy * dy;
        if (d2 < d2max) {
          final a = (lineAlpha * (1 - math.sqrt(d2) / connectDist)).toInt();
          if (a > 0) {
            canvas.drawLine(
              Offset(nodes[i].x, nodes[i].y),
              Offset(nodes[j].x, nodes[j].y),
              Paint()..color = color.withAlpha(a)..strokeWidth = 1,
            );
          }
        }
      }
    }
    // points
    for (final n in nodes) {
      canvas.drawCircle(Offset(n.x, n.y), 2.5,
          Paint()..color = color.withAlpha(pointAlpha));
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter o) => true;
}
