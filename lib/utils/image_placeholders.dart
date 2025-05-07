import 'package:flutter/material.dart';

class ImagePlaceholders {
  // This class provides placeholder widgets to use instead of actual image files
  
  static Widget waterDrop({double? width, double? height, Color color = Colors.blue}) {
    // Using a widget builder to handle non-const color parameter
    // while still enabling the const constructor for the painter
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: WaterDropPainter(color: color),
        size: Size(width ?? 150, height ?? 150),
      ),
    );
  }
  
  static Widget tankDiagram({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CustomPaint(
        painter: const TankDiagramPainter(),
        size: Size(width ?? 200, height ?? 200),
      ),
    );
  }
  
  static Widget waterDrops({double? width, double? height}) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: const WaterDropsPainter(),
        size: Size(width ?? 100, height ?? 60),
      ),
    );
  }
}

class WaterDropPainter extends CustomPainter {
  final Color color;
  
  const WaterDropPainter({this.color = Colors.blue});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Draw a simple water drop shape
    path.moveTo(centerX, centerY - size.height * 0.4);
    path.quadraticBezierTo(
      centerX + size.width * 0.4, centerY, 
      centerX, centerY + size.height * 0.4
    );
    path.quadraticBezierTo(
      centerX - size.width * 0.4, centerY, 
      centerX, centerY - size.height * 0.4
    );
    
    canvas.drawPath(path, paint);
    
    // Add a highlight effect
    final highlightPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.3)
      ..style = PaintingStyle.fill;
    
    final highlightPath = Path();
    highlightPath.moveTo(centerX - size.width * 0.2, centerY - size.height * 0.2);
    highlightPath.quadraticBezierTo(
      centerX - size.width * 0.1, centerY - size.height * 0.1,
      centerX, centerY - size.height * 0.1
    );
    highlightPath.quadraticBezierTo(
      centerX + size.width * 0.1, centerY - size.height * 0.1,
      centerX + size.width * 0.2, centerY - size.height * 0.2
    );
    highlightPath.close();
    
    canvas.drawPath(highlightPath, highlightPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TankDiagramPainter extends CustomPainter {
  const TankDiagramPainter();
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint tankPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    final Paint waterPaint = Paint()
      ..color = Colors.blue.shade400
      ..style = PaintingStyle.fill;
    
    final Paint levelPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw tank outline
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.1, size.width * 0.6, size.height * 0.8),
      const Radius.circular(10),
    );
    canvas.drawRRect(tankRect, tankPaint);
    
    // Draw water level
    final waterRect = Rect.fromLTWH(
      size.width * 0.2, 
      size.height * 0.4, 
      size.width * 0.6, 
      size.height * 0.5,
    );
    canvas.drawRect(waterRect, waterPaint);
    
    // Draw level markers
    for (var i = 1; i <= 5; i++) {
      final y = size.height * 0.1 + (size.height * 0.8 / 5 * i);
      canvas.drawLine(
        Offset(size.width * 0.2 - 5, y),
        Offset(size.width * 0.2, y),
        levelPaint,
      );
      
      // Add level text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${100 - i * 20}%',
          style: const TextStyle(color: Colors.black, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(canvas, Offset(size.width * 0.1, y - 5));
    }
    
    // Draw inlet pipe
    final inletPath = Path();
    inletPath.moveTo(size.width * 0.1, size.height * 0.3);
    inletPath.lineTo(size.width * 0.2, size.height * 0.3);
    canvas.drawPath(inletPath, tankPaint);
    
    // Draw outlet pipe
    final outletPath = Path();
    outletPath.moveTo(size.width * 0.2, size.height * 0.7);
    outletPath.lineTo(size.width * 0.1, size.height * 0.7);
    canvas.drawPath(outletPath, tankPaint);
    
    // Draw water sensor
    final sensorPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 5, sensorPaint);
    
    // Draw a simple controller
    final controllerPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final controllerRect = Rect.fromLTWH(
      size.width * 0.85,
      size.height * 0.4,
      size.width * 0.1,
      size.height * 0.2,
    );
    canvas.drawRect(controllerRect, controllerPaint);
    
    // Draw dotted lines for connection
    final dotPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    drawDottedLine(
      canvas, 
      Offset(size.width * 0.8, size.height * 0.3), 
      Offset(size.width * 0.85, size.height * 0.5), 
      dotPaint,
    );
  }
  
  void drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5;
    const dashSpace = 3;
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final count = (dx.abs() + dy.abs()) / (dashWidth + dashSpace);
    
    final xStep = dx / count;
    final yStep = dy / count;
    
    var startX = start.dx;
    var startY = start.dy;
    
    for (var i = 0; i < count; i += 2) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + xStep, startY + yStep),
        paint,
      );
      
      startX += (dashWidth + dashSpace) * xStep / (dashWidth + dashSpace);
      startY += (dashWidth + dashSpace) * yStep / (dashWidth + dashSpace);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaterDropsPainter extends CustomPainter {
  const WaterDropsPainter();
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    // Draw multiple small water drops
    _drawDrop(canvas, Offset(size.width * 0.3, size.height * 0.5), size.width * 0.1, paint);
    _drawDrop(canvas, Offset(size.width * 0.5, size.height * 0.3), size.width * 0.15, paint);
    _drawDrop(canvas, Offset(size.width * 0.7, size.height * 0.6), size.width * 0.12, paint);
  }
  
  void _drawDrop(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(
      center.dx + radius, center.dy, 
      center.dx, center.dy + radius
    );
    path.quadraticBezierTo(
      center.dx - radius, center.dy, 
      center.dx, center.dy - radius
    );
    
    canvas.drawPath(path, paint);
    
    // Add highlight
    final highlightPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.3)
      ..style = PaintingStyle.fill;
    
    final highlightPath = Path();
    highlightPath.moveTo(center.dx - radius * 0.5, center.dy - radius * 0.5);
    highlightPath.quadraticBezierTo(
      center.dx - radius * 0.25, center.dy - radius * 0.25,
      center.dx, center.dy - radius * 0.3
    );
    highlightPath.quadraticBezierTo(
      center.dx + radius * 0.25, center.dy - radius * 0.25,
      center.dx + radius * 0.5, center.dy - radius * 0.5
    );
    highlightPath.close();
    
    canvas.drawPath(highlightPath, highlightPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 