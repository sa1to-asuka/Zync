import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/utils/exif_helper.dart';

/// 相机品牌自动识别枚举（参考 semi-utils / PicSeal 自动匹配相机品牌标识）
enum CameraBrandType {
  nikon,
  canon,
  sony,
  fujifilm,
  leica,
  hasselblad,
  panasonic,
  olympus,
  ricoh,
  dji,
  apple,
  generic,
}

/// 纯 Canvas 矢量相机品牌标识渲染器。
///
/// 根据 EXIF 中的 `cameraMake` / `cameraModel` 自动识别相机品牌，
/// 并在水印中绘制高分辨率矢量品牌徽标（无需外部位图文件，任意缩放不失真）。
class CameraBrandEmblem {
  CameraBrandEmblem._();

  /// 从拍摄元数据自动识别品牌
  static CameraBrandType detect(PhotoMetadata meta) {
    final combined = '${meta.cameraMake} ${meta.cameraModel}'.toUpperCase();
    if (combined.contains('NIKON') ||
        RegExp(r'\bZ\s*(30|50|FC|F|5|6|7|8|9)\b').hasMatch(combined) ||
        RegExp(r'\bD(850|780|750|500|810|610|7500)\b').hasMatch(combined)) {
      return CameraBrandType.nikon;
    }
    if (combined.contains('CANON') || combined.contains('EOS')) {
      return CameraBrandType.canon;
    }
    if (combined.contains('SONY') ||
        combined.contains('ILCE') ||
        combined.contains('ALPHA')) {
      return CameraBrandType.sony;
    }
    if (combined.contains('FUJI') ||
        combined.contains('X-T') ||
        combined.contains('X100') ||
        combined.contains('GFX')) {
      return CameraBrandType.fujifilm;
    }
    if (combined.contains('LEICA')) {
      return CameraBrandType.leica;
    }
    if (combined.contains('HASSELBLAD') || combined.contains('X2D')) {
      return CameraBrandType.hasselblad;
    }
    if (combined.contains('PANASONIC') || combined.contains('LUMIX')) {
      return CameraBrandType.panasonic;
    }
    if (combined.contains('OLYMPUS') || combined.contains('OM SYSTEM') || combined.contains('OM-')) {
      return CameraBrandType.olympus;
    }
    if (combined.contains('RICOH') || combined.contains('PENTAX')) {
      return CameraBrandType.ricoh;
    }
    if (combined.contains('DJI') || combined.contains('MAVIC') || combined.contains('OSMO')) {
      return CameraBrandType.dji;
    }
    if (combined.contains('APPLE') || combined.contains('IPHONE')) {
      return CameraBrandType.apple;
    }
    return CameraBrandType.generic;
  }

  /// 测算品牌徽标在指定高度下的理想宽度
  static Size measure(
    PhotoMetadata meta, {
    required double height,
  }) {
    final brand = detect(meta);
    return switch (brand) {
      CameraBrandType.leica => Size(height * 1.15, height),
      CameraBrandType.nikon => Size(height * 2.55, height),
      CameraBrandType.canon => Size(height * 2.40, height),
      CameraBrandType.sony => Size(height * 2.65, height),
      CameraBrandType.fujifilm => Size(height * 2.85, height),
      CameraBrandType.hasselblad => Size(height * 3.20, height),
      CameraBrandType.panasonic => Size(height * 2.45, height),
      CameraBrandType.olympus => Size(height * 2.30, height),
      CameraBrandType.ricoh => Size(height * 2.35, height),
      CameraBrandType.dji => Size(height * 1.65, height),
      CameraBrandType.apple => Size(height * 2.15, height),
      CameraBrandType.generic => Size(height * 2.20, height),
    };
  }

  /// 在 [rect] 区域内绘制品牌矢量徽标
  static void paint(
    Canvas canvas,
    Rect rect,
    PhotoMetadata meta, {
    required Color textColor,
    required Color accentColor,
    double opacity = 1.0,
  }) {
    final brand = detect(meta);
    final h = rect.height;
    final cy = rect.center.dy;
    final fg = textColor.withValues(alpha: (textColor.a * opacity).clamp(0.0, 1.0));

    canvas.save();
    switch (brand) {
      case CameraBrandType.nikon:
        _paintNikon(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.canon:
        _paintCanon(canvas, rect, h, cy, opacity);
        break;
      case CameraBrandType.sony:
        _paintSony(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.fujifilm:
        _paintFujifilm(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.leica:
        _paintLeica(canvas, rect, h, cy, opacity);
        break;
      case CameraBrandType.hasselblad:
        _paintHasselblad(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.panasonic:
        _paintLumix(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.olympus:
        _paintOmSystem(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.ricoh:
        _paintRicoh(canvas, rect, h, cy, fg, opacity);
        break;
      case CameraBrandType.dji:
        _paintDji(canvas, rect, h, cy, fg);
        break;
      case CameraBrandType.apple:
        _paintApple(canvas, rect, h, cy, fg, accentColor, opacity);
        break;
      case CameraBrandType.generic:
        _paintGeneric(canvas, rect, h, cy, meta, fg, accentColor, opacity);
        break;
    }
    canvas.restore();
  }

  static void _paintNikon(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    // 尼康经典黄斜切光束条 + 斜体粗体 Nikon 字标
    final nikonYellow = const Color(0xFFFFD100).withValues(alpha: opacity);
    final nikonRed = const Color(0xFFE60012).withValues(alpha: opacity);

    // 左侧尼康红裤衩斜切与金黄标识条
    final stripeW = h * 0.24;
    final stripeH = h * 0.68;
    final sx = rect.left + h * 0.06;
    final sy = cy - stripeH * 0.5;
    final slant = stripeH * 0.24;

    final redPath = Path()
      ..moveTo(sx + slant, sy)
      ..lineTo(sx + slant + stripeW * 0.48, sy)
      ..lineTo(sx + stripeW * 0.48, sy + stripeH)
      ..lineTo(sx, sy + stripeH)
      ..close();
    canvas.drawPath(redPath, Paint()..color = nikonRed);

    final yellowPath = Path()
      ..moveTo(sx + slant + stripeW * 0.62, sy)
      ..lineTo(sx + slant + stripeW * 1.05, sy)
      ..lineTo(sx + stripeW * 1.05, sy + stripeH)
      ..lineTo(sx + stripeW * 0.62, sy + stripeH)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = nikonYellow);

    final tp = _buildText(
      'Nikon',
      TextStyle(
        color: fg,
        fontSize: h * 0.66,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -h * 0.02,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(sx + stripeW * 1.38, cy - tp.height / 2));
  }

  static void _paintCanon(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    double opacity,
  ) {
    final canonRed = const Color(0xFFCC0000).withValues(alpha: opacity);
    final tp = _buildText(
      'Canon',
      TextStyle(
        color: canonRed,
        fontSize: h * 0.68,
        fontWeight: FontWeight.w900,
        letterSpacing: h * 0.01,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, cy - tp.height / 2));
  }

  static void _paintSony(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    final alphaOrange = const Color(0xFFFF5500).withValues(alpha: opacity);
    final sonyTp = _buildText(
      'SONY',
      TextStyle(
        color: fg,
        fontSize: h * 0.54,
        fontWeight: FontWeight.w800,
        letterSpacing: h * 0.06,
        height: 1.0,
      ),
    );
    final alphaTp = _buildText(
      'α',
      TextStyle(
        color: alphaOrange,
        fontSize: h * 0.72,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        height: 1.0,
      ),
    );
    final totalW = sonyTp.width + h * 0.18 + alphaTp.width;
    final startX = rect.left + (rect.width - totalW) / 2;
    sonyTp.paint(canvas, Offset(startX, cy - sonyTp.height / 2));
    alphaTp.paint(
      canvas,
      Offset(startX + sonyTp.width + h * 0.18, cy - alphaTp.height * 0.54),
    );
  }

  static void _paintFujifilm(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    final fujiRed = const Color(0xFFE60012).withValues(alpha: opacity);
    final tp = _buildText(
      'FUJIFILM',
      TextStyle(
        color: fg,
        fontSize: h * 0.50,
        fontWeight: FontWeight.w900,
        letterSpacing: h * 0.05,
        height: 1.0,
      ),
    );
    final tx = rect.left + (rect.width - tp.width) / 2;
    tp.paint(canvas, Offset(tx, cy - tp.height / 2));

    // 底部经典富士红点睛短横线
    final barW = tp.width * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx + (tp.width - barW) / 2, cy + tp.height * 0.54, barW, h * 0.07),
        Radius.circular(h * 0.04),
      ),
      Paint()..color = fujiRed,
    );
  }

  static void _paintLeica(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    double opacity,
  ) {
    final leicaRed = const Color(0xFFE30613).withValues(alpha: opacity);
    final white = Colors.white.withValues(alpha: opacity);
    final r = h * 0.44;
    final center = Offset(rect.center.dx, cy);
    canvas.drawCircle(center, r, Paint()..color = leicaRed);
    final tp = _buildText(
      'Leica',
      TextStyle(
        color: white,
        fontSize: h * 0.34,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -h * 0.01,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  static void _paintHasselblad(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    final tp = _buildText(
      'HASSELBLAD',
      TextStyle(
        color: fg,
        fontSize: h * 0.42,
        fontWeight: FontWeight.w800,
        letterSpacing: h * 0.09,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, cy - tp.height / 2));
  }

  static void _paintLumix(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    final lumixRed = const Color(0xFFE60012).withValues(alpha: opacity);
    final tp = _buildText(
      'LUMIX',
      TextStyle(
        color: fg,
        fontSize: h * 0.54,
        fontWeight: FontWeight.w900,
        letterSpacing: h * 0.06,
        height: 1.0,
      ),
    );
    final tx = rect.left + (rect.width - tp.width) / 2;
    tp.paint(canvas, Offset(tx, cy - tp.height / 2));
    canvas.drawCircle(
      Offset(tx - h * 0.14, cy),
      h * 0.08,
      Paint()..color = lumixRed,
    );
  }

  static void _paintOmSystem(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    final tp = _buildText(
      'OM SYSTEM',
      TextStyle(
        color: fg,
        fontSize: h * 0.46,
        fontWeight: FontWeight.w800,
        letterSpacing: h * 0.05,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, cy - tp.height / 2));
  }

  static void _paintRicoh(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    double opacity,
  ) {
    final grRed = const Color(0xFFD9232E).withValues(alpha: opacity);
    final tp = _buildText(
      'GR',
      TextStyle(
        color: grRed,
        fontSize: h * 0.54,
        fontWeight: FontWeight.w900,
        letterSpacing: h * 0.02,
        height: 1.0,
      ),
    );
    final ricohTp = _buildText(
      'RICOH',
      TextStyle(
        color: fg,
        fontSize: h * 0.48,
        fontWeight: FontWeight.w800,
        letterSpacing: h * 0.05,
        height: 1.0,
      ),
    );
    final totalW = ricohTp.width + h * 0.16 + tp.width;
    final sx = rect.left + (rect.width - totalW) / 2;
    ricohTp.paint(canvas, Offset(sx, cy - ricohTp.height / 2));
    tp.paint(canvas, Offset(sx + ricohTp.width + h * 0.16, cy - tp.height / 2));
  }

  static void _paintDji(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
  ) {
    final tp = _buildText(
      'DJI',
      TextStyle(
        color: fg,
        fontSize: h * 0.64,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: h * 0.04,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, cy - tp.height / 2));
  }

  static void _paintApple(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    Color fg,
    Color accent,
    double opacity,
  ) {
    _drawApertureIcon(
      canvas,
      Offset(rect.left + h * 0.34, cy),
      h * 0.26,
      accent.withValues(alpha: opacity),
    );
    final tp = _buildText(
      'iPhone',
      TextStyle(
        color: fg,
        fontSize: h * 0.52,
        fontWeight: FontWeight.w700,
        letterSpacing: h * 0.01,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(rect.left + h * 0.72, cy - tp.height / 2));
  }

  static void _paintGeneric(
    Canvas canvas,
    Rect rect,
    double h,
    double cy,
    PhotoMetadata meta,
    Color fg,
    Color accent,
    double opacity,
  ) {
    _drawApertureIcon(
      canvas,
      Offset(rect.left + h * 0.34, cy),
      h * 0.26,
      accent.withValues(alpha: opacity),
    );
    final label = meta.cameraMake.trim().isNotEmpty
        ? meta.cameraMake.trim().toUpperCase()
        : 'CAMERA';
    final tp = _buildText(
      label,
      TextStyle(
        color: fg,
        fontSize: h * 0.48,
        fontWeight: FontWeight.w800,
        letterSpacing: h * 0.04,
        height: 1.0,
      ),
    );
    tp.paint(canvas, Offset(rect.left + h * 0.72, cy - tp.height / 2));
  }

  static void _drawApertureIcon(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18;
    canvas.drawCircle(center, radius, ringPaint);
    final bladePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.13
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final a1 = i * math.pi / 3;
      final a2 = a1 + math.pi / 2.4;
      final p1 = Offset(
        center.dx + radius * 0.92 * math.cos(a1),
        center.dy + radius * 0.92 * math.sin(a1),
      );
      final p2 = Offset(
        center.dx + radius * 0.42 * math.cos(a2),
        center.dy + radius * 0.42 * math.sin(a2),
      );
      canvas.drawLine(p1, p2, bladePaint);
    }
  }

  static TextPainter _buildText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    tp.layout();
    return tp;
  }
}
