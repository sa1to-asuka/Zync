import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/utils/exif_helper.dart';
import '../filter/photo_filter.dart';
import 'camera_brand_emblem.dart';
import 'watermark_template.dart';

/// 画布总尺寸与源图片放置矩形结果
class LayoutMetrics {
  final double totalWidth;
  final double totalHeight;
  final Rect imageRect;

  const LayoutMetrics({
    required this.totalWidth,
    required this.totalHeight,
    required this.imageRect,
  });
}

/// 摄影画廊级水印排版绘制引擎 (精编 9 大高质感模板 · 彻底淘汰同质化低质边框)
/// 核心采用基于 1200px 基准的标准动态缩放公式: scale = canvasWidth / 1200.0
class WatermarkCanvasPainter extends CustomPainter {
  final ui.Image? image;
  final PhotoMetadata metadata;
  final WatermarkTemplate template;
  final PhotoFilterType filterType;
  final double filterIntensity;
  final PhotoEditAdjustments adjustments;
  final double spacingScale;
  final bool showDetails;

  /// 边框/卡片底色是否为黑底 (false = 白底)
  final bool cardDark;

  /// 字体颜色是否为黑字 (false = 白字)
  final bool textDark;

  /// 用户覆盖的边框/底色；null = 使用模板默认逻辑
  final Color? cardColorOverride;

  /// 用户覆盖的字体颜色；null = 使用模板默认逻辑
  final Color? textColorOverride;

  /// 标题/机型字号倍率
  final double titleTextScale;

  /// 参数/副标题字号倍率
  final double metaTextScale;

  /// 字距倍率
  final double letterSpacingScale;

  /// 行距倍率
  final double lineSpacingScale;

  /// 全局字重覆盖
  final WatermarkFontWeight fontWeight;

  /// 边框/线条厚度倍率
  final double borderThicknessScale;

  /// 水印字体 (null = 各文字保持模板原生字体)
  final String? fontFamily;
  final int quarterTurns;
  final bool mirrorX;

  /// 自定义文字（最多取前 2 行，如版权 / 署名）
  final List<String> customLines;

  /// 自定义文字字号倍率（0.8 / 1.0 / 1.4）
  final double customTextScale;

  /// Logo 贴图（会话内选择，不持久化）
  final ui.Image? logoImage;

  /// Logo 宽度占图片宽度的比例（0.10 / 0.16 / 0.24）
  final double logoScale;

  /// Logo 不透明度（1.0 / 0.7 / 0.4）
  final double logoOpacity;

  /// 强调色：徽标、分割线、高亮参数
  final Color accentColor;

  /// 卡片底色基调（auto = 沿用模板原有的 cardDark 逻辑）
  final WatermarkCardTone cardTone;

  /// 卡片圆角倍率（0 = 直角，1 = 默认，2 = 更圆）
  final double cornerRadiusFactor;

  /// 内容显示开关（细分到单项）
  final bool showModel;
  final bool showLens;
  final bool showExposure;
  final bool showDate;
  final bool showBrandLogo;
  final bool showGps;

  /// 水印整体不透明度（1.0 / 0.85 / 0.7）
  final double watermarkOpacity;

  /// 自定义文字对齐与 Logo 位置
  final WatermarkTextAlign customTextAlign;
  final WatermarkLogoCorner logoCorner;

  WatermarkCanvasPainter({
    required this.image,
    required this.metadata,
    required this.template,
    this.filterType = PhotoFilterType.original,
    this.filterIntensity = 1.0,
    this.adjustments = const PhotoEditAdjustments(),
    this.spacingScale = 1.0,
    this.showDetails = true,
    this.cardDark = false,
    this.textDark = false,
    this.cardColorOverride,
    this.textColorOverride,
    this.titleTextScale = 1.0,
    this.metaTextScale = 1.0,
    this.letterSpacingScale = 1.0,
    this.lineSpacingScale = 1.0,
    this.fontWeight = WatermarkFontWeight.auto,
    this.borderThicknessScale = 1.0,
    this.fontFamily,
    this.quarterTurns = 0,
    this.mirrorX = false,
    this.customLines = const [],
    this.customTextScale = 1.0,
    this.logoImage,
    this.logoScale = 0.16,
    this.logoOpacity = 1.0,
    this.accentColor = const Color(0xFFFFD100),
    this.cardTone = WatermarkCardTone.auto,
    this.cornerRadiusFactor = 1.0,
    this.showModel = true,
    this.showLens = true,
    this.showExposure = true,
    this.showDate = true,
    this.showBrandLogo = true,
    this.showGps = true,
    this.watermarkOpacity = 1.0,
    this.customTextAlign = WatermarkTextAlign.left,
    this.logoCorner = WatermarkLogoCorner.bottomRight,
  });

  /// 计算在给定源图尺寸与模板下的目标排版画布尺寸与图片放置位置
  static LayoutMetrics computeLayout(double srcW, double srcH, WatermarkTemplate template, [double spacing = 1.0]) {
    // 水印字号以 1200px 设计基准等比缩放；输入低于基准时整体等比放大光栅
    // (版式比例不变，照片随之放大)，否则低分辨率裁切后字号过小、导出糊成一团。
    if (template != WatermarkTemplate.none && srcW < 1200) {
      srcH *= 1200 / srcW;
      srcW = 1200;
    }
    switch (template) {
      case WatermarkTemplate.none: {
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.inPhotoOverlay: {
        // 满幅无边框，文字排在照片内部
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.bottomBannerBlur: {
        // 周围全幅高斯虚化 + 纯下边框 (图片左右上与卡片齐平，无多余白边)
        final marginX = srcW * 0.07 * spacing;
        final marginY = srcH * 0.07 * spacing;
        final bottomH = srcH * 0.15 * spacing;
        final totalW = srcW + marginX * 2;
        final totalH = srcH + bottomH + marginY * 2;
        return LayoutMetrics(
          totalWidth: totalW,
          totalHeight: totalH,
          imageRect: Rect.fromLTWH(marginX, marginY, srcW, srcH),
        );
      }
      case WatermarkTemplate.topBottomBannerBlur: {
        // 周围全幅高斯虚化 + 上下双边框 (顶部 LIGHT AND SHADOW，底部大师参数)
        final marginX = srcW * 0.07 * spacing;
        final marginY = srcH * 0.07 * spacing;
        final topH = srcH * 0.09 * spacing;
        final bottomH = srcH * 0.15 * spacing;
        final totalW = srcW + marginX * 2;
        final totalH = srcH + topH + bottomH + marginY * 2;
        return LayoutMetrics(
          totalWidth: totalW,
          totalHeight: totalH,
          imageRect: Rect.fromLTWH(marginX, marginY + topH, srcW, srcH),
        );
      }
      case WatermarkTemplate.darkGlassBlur: {
        // 周围暗调虚化 + 悬浮磨砂黑玻质感卡片
        final marginX = srcW * 0.065 * spacing;
        final marginY = srcH * 0.065 * spacing;
        final topH = srcH * 0.05 * spacing;
        final bottomH = srcH * 0.15 * spacing;
        final totalW = srcW + marginX * 2;
        final totalH = srcH + topH + bottomH + marginY * 2;
        return LayoutMetrics(
          totalWidth: totalW,
          totalHeight: totalH,
          imageRect: Rect.fromLTWH(marginX, marginY + topH, srcW, srcH),
        );
      }
      case WatermarkTemplate.polaroidBlur: {
        // 周围全幅高斯虚化 + 浮动复古白卡立体相纸
        final pad = srcW * 0.032 * spacing;
        final marginX = srcW * 0.06 * spacing;
        final marginY = srcH * 0.06 * spacing;
        final bottomH = srcH * 0.16 * spacing;
        final cardW = srcW + pad * 2;
        final cardH = srcH + pad + bottomH;
        final totalW = cardW + marginX * 2;
        final totalH = cardH + marginY * 2;
        return LayoutMetrics(
          totalWidth: totalW,
          totalHeight: totalH,
          imageRect: Rect.fromLTWH(marginX + pad, marginY + pad, srcW, srcH),
        );
      }
      case WatermarkTemplate.flushMasterBar: {
        // 大师画廊 · 纯净直出底栏 (零虚化，满幅照片直接拼接)
        final bottomH = srcH * 0.13 * spacing;
        final totalH = srcH + bottomH;
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: totalH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.magazineCover: {
        // 杂志封面：顶部大标题区 + 底部信息区，四周留白卡片
        final marginX = srcW * 0.05 * spacing;
        final marginY = srcH * 0.05 * spacing;
        final topH = srcH * 0.11 * spacing;
        final bottomH = srcH * 0.13 * spacing;
        return LayoutMetrics(
          totalWidth: srcW + marginX * 2,
          totalHeight: srcH + topH + bottomH + marginY * 2,
          imageRect: Rect.fromLTWH(marginX, marginY + topH, srcW, srcH),
        );
      }
      case WatermarkTemplate.gradientCaption: {
        // 渐变字幕：满幅照片，底部渐变遮罩压字
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.minimalLine: {
        // 极简细线：满幅照片 + 内嵌细框
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.brandClassicWhite: {
        // 经典白边 · 品牌框 (Copicseal / PicSeal 风格：纯下底栏拼接)
        final bottomH = srcH * 0.135 * spacing;
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH + bottomH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.brandEmblemCenter: {
        // 徽标居中 · 展签框 (semi-utils 风格：四周留白 + 底部居中品牌徽标与参数)
        final pad = srcW * 0.036 * spacing;
        final bottomH = srcH * 0.18 * spacing;
        return LayoutMetrics(
          totalWidth: srcW + pad * 2,
          totalHeight: srcH + pad + bottomH,
          imageRect: Rect.fromLTWH(pad, pad, srcW, srcH),
        );
      }
      case WatermarkTemplate.blurFloatingShadow: {
        // 圆角阴影 · 品牌悬浮 (semi-utils / camera-watermark 风格：模糊底 + 悬浮圆角阴影 + 底部徽标)
        final marginX = srcW * 0.075 * spacing;
        final topMargin = srcH * 0.07 * spacing;
        final bottomH = srcH * 0.16 * spacing;
        return LayoutMetrics(
          totalWidth: srcW + marginX * 2,
          totalHeight: srcH + topMargin + bottomH,
          imageRect: Rect.fromLTWH(marginX, topMargin, srcW, srcH),
        );
      }
      case WatermarkTemplate.minimalCornerParam: {
        // 右下角 · 极简参数 (semi-utils 风格：无外框内嵌)
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.retroTimestamp: {
        // 复古胶片 · 日期戳 (Copicseal 风格：无外框胶片时间戳)
        return LayoutMetrics(
          totalWidth: srcW,
          totalHeight: srcH,
          imageRect: Rect.fromLTWH(0, 0, srcW, srcH),
        );
      }
      case WatermarkTemplate.geoLocationEditorial: {
        // 地理坐标 · 经纬度展签 (四周细白边 + 底部经纬度与品牌展签)
        final pad = srcW * 0.024 * spacing;
        final bottomH = srcH * 0.155 * spacing;
        return LayoutMetrics(
          totalWidth: srcW + pad * 2,
          totalHeight: srcH + pad + bottomH,
          imageRect: Rect.fromLTWH(pad, pad, srcW, srcH),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (image != null) {
      _paintFullComposite(canvas, size, image!);
    } else {
      _paintPlaceholderPreview(canvas, size);
    }
  }

  /// 绘制无图时的摄影展签占位画布
  void _paintPlaceholderPreview(Canvas canvas, Size size) {
    final layout = computeLayout(1200, 800, template, spacingScale);
    // contain 适配：按排版比例完整呈现居中，画布外留白保持透明 (所见即所得，不铺任何装饰底)
    final scaleRatio = math.min(size.width / layout.totalWidth, size.height / layout.totalHeight);
    final offsetX = (size.width - layout.totalWidth * scaleRatio) / 2.0;
    final offsetY = (size.height - layout.totalHeight * scaleRatio) / 2.0;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scaleRatio, scaleRatio);

    final fittedCanvasSize = Size(layout.totalWidth, layout.totalHeight);
    _drawAllOverlays(canvas, fittedCanvasSize, null, layout.imageRect);
    canvas.restore();
  }

  /// 绘制实际图像与完整水印排版
  void _paintFullComposite(Canvas canvas, Size size, ui.Image img) {
    final rotated = quarterTurns % 2 != 0;
    final srcW = rotated ? img.height.toDouble() : img.width.toDouble();
    final srcH = rotated ? img.width.toDouble() : img.height.toDouble();
    final layout = computeLayout(srcW, srcH, template, spacingScale);
    // contain 适配：画布与排版比例不一致时整体缩放居中，不裁切、不加装饰底 (所见即所得)
    final scaleRatio = math.min(size.width / layout.totalWidth, size.height / layout.totalHeight);
    final offsetX = (size.width - layout.totalWidth * scaleRatio) / 2.0;
    final offsetY = (size.height - layout.totalHeight * scaleRatio) / 2.0;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scaleRatio, scaleRatio);

    final fittedCanvasSize = Size(layout.totalWidth, layout.totalHeight);
    _drawAllOverlays(canvas, fittedCanvasSize, img, layout.imageRect);
    canvas.restore();
  }

  void _drawTemplateOverlays(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    switch (template) {
      case WatermarkTemplate.none:
        if (img != null) {
          _drawImageWithFilter(canvas, img, imgRect);
        } else {
          _drawNonePlaceholder(canvas, size);
        }
        break;
      case WatermarkTemplate.inPhotoOverlay:
        _drawInPhotoOverlay(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.bottomBannerBlur:
        _drawBottomBannerBlur(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.topBottomBannerBlur:
        _drawTopBottomBannerBlur(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.darkGlassBlur:
        _drawDarkGlassBlur(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.polaroidBlur:
        _drawPolaroidBlur(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.flushMasterBar:
        _drawFlushMasterBar(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.magazineCover:
        _drawMagazineCover(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.gradientCaption:
        _drawGradientCaption(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.minimalLine:
        _drawMinimalLine(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.brandClassicWhite:
        _drawBrandClassicWhite(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.brandEmblemCenter:
        _drawBrandEmblemCenter(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.blurFloatingShadow:
        _drawBlurFloatingShadow(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.minimalCornerParam:
        _drawMinimalCornerParam(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.retroTimestamp:
        _drawRetroTimestamp(canvas, size, img, imgRect);
        break;
      case WatermarkTemplate.geoLocationEditorial:
        _drawGeoLocationEditorial(canvas, size, img, imgRect);
        break;
    }
    // 自定义文字与 Logo 与模板正交，所有模板都叠加绘制
    _drawCustomLayer(canvas, imgRect);
  }

  /// 4 款新模板与自定义图层统一走这里，实现「整体不透明度」一档生效。
  void _drawAllOverlays(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final opacity = watermarkOpacity.clamp(0.1, 1.0);
    if (opacity >= 0.999) {
      _drawTemplateOverlays(canvas, size, img, imgRect);
      return;
    }
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    _drawTemplateOverlays(canvas, size, img, imgRect);
    canvas.restore();
  }

  /// 按内容开关过滤后的元数据：模板内部一律读它，开关对全部模板生效。
  PhotoMetadata get _meta {
    if (showModel && showLens && showExposure && showDate && showGps) {
      return metadata;
    }
    return PhotoMetadata(
      cameraMake: metadata.cameraMake,
      cameraModel: showModel ? metadata.cameraModel : '',
      lensModel: showLens ? metadata.lensModel : '',
      shutterSpeed: showExposure ? metadata.shutterSpeed : '',
      aperture: showExposure ? metadata.aperture : '',
      iso: showExposure ? metadata.iso : '',
      focalLength: showExposure ? metadata.focalLength : '',
      capturedDate: showDate ? metadata.capturedDate : '',
      orientation: metadata.orientation,
      width: metadata.width,
      height: metadata.height,
      latitude: showGps ? metadata.latitude : null,
      longitude: showGps ? metadata.longitude : null,
      altitude: showGps ? metadata.altitude : null,
    );
  }

  /// 卡片底色：用户覆盖色优先，其次按卡片基调，最后沿用模板默认色。
  Color _cardFill(Color autoFill) {
    final override = cardColorOverride;
    if (override != null) return override;
    return switch (cardTone) {
      WatermarkCardTone.white => Colors.white,
      WatermarkCardTone.black => const Color(0xFF101216),
      WatermarkCardTone.cream => const Color(0xFFF5F1E8),
      WatermarkCardTone.auto => autoFill,
    };
  }

  /// 根据最终卡片颜色决定阴影深浅，保证自定义浅/深色都自然。
  bool _isEffectiveCardDark(Color autoFill) {
    final fill = _cardFill(autoFill);
    return fill.computeLuminance() < 0.45;
  }

  /// 字体颜色覆盖：null 时保留模板原有层级色。
  Color _textColor(Color fallback, [double opacity = 1.0]) {
    final override = textColorOverride;
    if (override == null) return fallback;
    return override.withAlpha((255 * opacity.clamp(0.0, 1.0)).round());
  }

  /// 自定义字体色下的次级文字：同色降透明度，保持信息层级。
  Color _secondaryTextColor(Color fallback) => _textColor(fallback, 0.72);

  /// 自定义字体色下的阴影：亮字配黑阴影，暗字配白阴影。
  Color _textShadowColor(Color fallback) {
    final override = textColorOverride;
    if (override == null) return fallback;
    return override.computeLuminance() > 0.5
        ? const Color(0xAA000000)
        : const Color(0x99FFFFFF);
  }

  /// 三组独立字号倍率。
  double _titleSize(double base, double scale) =>
      base * scale * titleTextScale;

  double _metaSize(double base, double scale) => base * scale * metaTextScale;

  double _letter(double base, double scale) =>
      base * scale * letterSpacingScale;

  double _line(double base, double scale) => base * scale * lineSpacingScale;

  double _stroke(double base, double scale) =>
      base * scale * borderThicknessScale;

  /// 全局字重覆盖；auto 保留各模板原生字重。
  FontWeight _weight(FontWeight fallback) => switch (fontWeight) {
        WatermarkFontWeight.auto => fallback,
        WatermarkFontWeight.regular => FontWeight.w400,
        WatermarkFontWeight.medium => FontWeight.w600,
        WatermarkFontWeight.bold => FontWeight.w700,
        WatermarkFontWeight.black => FontWeight.w900,
      };

  /// 卡片圆角（0 = 直角）。
  Radius _cardRadius(double scale, [double base = 16]) =>
      Radius.circular(base * scale * cornerRadiusFactor);

  static bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 自定义图层：左下角文字（最多 2 行）+ 右下角 Logo。
  ///
  /// 与模板解耦，直接贴在图片区内，因此任何模板都能用；
  /// 文字带阴影保证在亮/暗背景上都可读。
  void _drawCustomLayer(Canvas canvas, Rect imgRect) {
    final inset = imgRect.width * 0.03;

    final logo = logoImage;
    if (logo != null) {
      final w = imgRect.width * logoScale;
      final h = w * (logo.height / logo.width);
      final left = switch (logoCorner) {
        WatermarkLogoCorner.topLeft ||
        WatermarkLogoCorner.bottomLeft =>
          imgRect.left + inset,
        _ => imgRect.right - w - inset,
      };
      final top = switch (logoCorner) {
        WatermarkLogoCorner.topLeft ||
        WatermarkLogoCorner.topRight =>
          imgRect.top + inset,
        _ => imgRect.bottom - h - inset,
      };
      final dst = Rect.fromLTWH(left, top, w, h);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: logoOpacity.clamp(0.0, 1.0));
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        dst,
        paint,
      );
    }

    final lines = customLines
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    if (lines.isEmpty) return;

    final fontSize = imgRect.width * 0.026 * customTextScale;
    final lineHeight = fontSize * 1.3 * lineSpacingScale;
    var top = imgRect.bottom - inset - lineHeight * lines.length;
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(
            color: _textColor(Colors.white),
            fontSize: fontSize,
            fontWeight: _weight(FontWeight.w600),
            fontFamily: fontFamily,
            letterSpacing: _letter(0.3, imgRect.width / 1200.0),
            shadows: [
              Shadow(
                color: _textShadowColor(Colors.black.withValues(alpha: 0.65)),
                blurRadius: fontSize * 0.3,
                offset: Offset(0, fontSize * 0.06),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imgRect.width * 0.6);
      final dx = switch (customTextAlign) {
        WatermarkTextAlign.left => imgRect.left + inset,
        WatermarkTextAlign.center => imgRect.center.dx - tp.width / 2,
        WatermarkTextAlign.right => imgRect.right - inset - tp.width,
      };
      _paintText(canvas, tp, Offset(dx, top));
      top += lineHeight;
    }
  }

  /// 绘制带滤镜与 Lightroom 调色参数的位图
  void _drawImageWithFilter(Canvas canvas, ui.Image img, Rect dstRect) {
    final paint = PhotoFilterEngine.createCompositeFilterPaint(
      filterType: filterType,
      filterIntensity: filterIntensity,
      adjustments: adjustments,
    );
    final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final turns = quarterTurns % 4;
    if (turns == 0 && !mirrorX) {
      canvas.drawImageRect(img, srcRect, dstRect, paint);
    } else {
      canvas.save();
      canvas.translate(dstRect.center.dx, dstRect.center.dy);
      if (mirrorX) canvas.scale(-1, 1);
      canvas.rotate(turns * math.pi / 2);
      final local = Rect.fromCenter(
        center: Offset.zero,
        width: turns.isOdd ? dstRect.height : dstRect.width,
        height: turns.isOdd ? dstRect.width : dstRect.height,
      );
      canvas.drawImageRect(img, srcRect, local, paint);
      canvas.restore();
    }

    // 绘制暗角
    if (adjustments.vignette.abs() >= 1.0) {
      PhotoFilterEngine.drawVignette(canvas, dstRect, adjustments.vignette);
    }

    // 绘制复古胶片颗粒
    if (adjustments.grain >= 1.0) {
      PhotoFilterEngine.drawGrain(canvas, dstRect, adjustments.grain);
    }
  }

  /// 绘制原图全景高斯虚化背景 (Gaussian Blur Background)
  void _drawGaussianBlurBackground(Canvas canvas, Size size, ui.Image? img, double scale, {double tintOpacity = 0.28}) {
    if (img != null) {
      final bgDst = Rect.fromLTWH(0, 0, size.width, size.height);
      final bgPaint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 42.0 * scale,
          sigmaY: 42.0 * scale,
          tileMode: TileMode.clamp,
        );

      final double srcAspect = img.width / img.height;
      final double dstAspect = size.width / size.height;
      Rect bgSrc;
      if (srcAspect > dstAspect) {
        final w = img.height * dstAspect;
        bgSrc = Rect.fromLTWH((img.width - w) / 2, 0, w, img.height.toDouble());
      } else {
        final h = img.width / dstAspect;
        bgSrc = Rect.fromLTWH(0, (img.height - h) / 2, img.width.toDouble(), h);
      }
      canvas.drawImageRect(img, bgSrc, bgDst, bgPaint);

      // 暗调遮罩层，提升悬浮卡片高对比度与空间深度感
      canvas.drawRect(bgDst, Paint()..color = Color.fromRGBO(0, 0, 0, tintOpacity));
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF1E2026));
    }
  }

  /// 绘制悬浮卡片双层多阶真实立体阴影
  void _drawFloatingShadow(Canvas canvas, RRect rrect, double scale, {bool isDark = false}) {
    // 1. 大范围空间漫反射柔和阴影
    canvas.drawRRect(
      rrect.shift(Offset(0, 16 * scale)),
      Paint()
        ..color = isDark ? const Color(0x66000000) : const Color(0x44000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 28 * scale),
    );
    // 2. 近距离实体接触投影 (提升紧致感)
    canvas.drawRRect(
      rrect.shift(Offset(0, 4 * scale)),
      Paint()
        ..color = isDark ? const Color(0x33000000) : const Color(0x22000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale),
    );
  }

  /// 照片绘制或占位符
  void _drawPhotoOrPlaceholder(Canvas canvas, ui.Image? img, Rect imgRect, double scale, {RRect? clipRRect}) {
    if (img != null) {
      if (clipRRect != null) {
        canvas.save();
        canvas.clipRRect(clipRRect);
        _drawImageWithFilter(canvas, img, imgRect);
        canvas.restore();
      } else {
        _drawImageWithFilter(canvas, img, imgRect);
      }
    } else {
      final phPaint = Paint()..color = const Color(0xFF1B1D24);
      if (clipRRect != null) {
        canvas.drawRRect(clipRRect, phPaint);
      } else {
        canvas.drawRect(imgRect, phPaint);
      }

      final phText = TextPainter(
        text: TextSpan(
          text: 'P H O T O   P R E V I E W',
          style: TextStyle(
            color: Colors.white24,
            fontSize: 20 * scale,
            fontWeight: FontWeight.bold,
            letterSpacing: 4 * scale,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      phText.paint(
        canvas,
        Offset(imgRect.left + (imgRect.width - phText.width) / 2, imgRect.top + (imgRect.height - phText.height) / 2),
      );
    }
  }

  void _drawNonePlaceholder(Canvas canvas, Size size) {
    final scale = size.width / 1200.0;
    final bgPaint = Paint()..color = const Color(0xFF16181D);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final titleP = TextPainter(
      text: TextSpan(
        text: '纯滤镜调色模式 (无水印)',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 22 * scale,
          fontWeight: FontWeight.bold,
          letterSpacing: 2 * scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, titleP, Offset((size.width - titleP.width) / 2, size.height * 0.45));

    final subP = TextPainter(
      text: TextSpan(
        text: '保持原始画幅比例 · 仅导出胶片色彩 · 零额外水印',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 13 * scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subP.paint(canvas, Offset((size.width - subP.width) / 2, size.height * 0.45 + 34 * scale));
  }

  /// 模板: 照片内嵌 · 参数入画 (满幅无边框，机型与曝光参数直接排在照片内部)
  void _drawInPhotoOverlay(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;

    // 1. 满幅照片 (无边框无虚化)
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    // 2. 用户选底色时，为内嵌文字铺一层低透明度底部遮罩，保证复杂照片上的可读性。
    final scrimColor = _cardFill(Colors.transparent);
    if (scrimColor.a > 0) {
      final maskH = imgRect.height * 0.42;
      final maskRect = Rect.fromLTWH(0, imgRect.bottom - maskH, imgRect.width, maskH);
      canvas.drawRect(
        maskRect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, maskRect.top),
            Offset(0, maskRect.bottom),
            [Colors.transparent, scrimColor.withAlpha(150)],
          ),
      );
    }

    // 3. 文字配色与投影 (反色投影保证任意照片上可读)
    final baseColor = _textColor(textDark ? Colors.black : Colors.white);
    final subColor = _secondaryTextColor(
        textDark ? Colors.black.withAlpha(175) : Colors.white.withAlpha(215));
    final shadowColor = _textShadowColor(
        textDark ? Colors.white.withAlpha(150) : Colors.black.withAlpha(170));
    final shadows = [
      Shadow(color: shadowColor, offset: Offset(0, 1.5 * scale), blurRadius: 6 * scale),
    ];

    final padX = size.width * 0.045 * spacingScale;
    final padY = size.height * 0.06 * spacingScale;
    final lineGap = _line(4, scale);
    final maxTextW = size.width * 0.5;

    // 3. 左下: 机型 (大字) + 镜头 (样式层注入字体，保留 maxWidth 截断)
    final titleP = TextPainter(
      text: TextSpan(
        text: _meta.titleText,
        style: _fontStyle(TextStyle(
          color: baseColor,
          fontSize: _titleSize(38, scale),
          fontWeight: FontWeight.w800,
          letterSpacing: _letter(0.5, scale),
          shadows: shadows,
        )),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextW);

    TextPainter? lensP;
    if (_meta.lensModel.isNotEmpty) {
      lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: _fontStyle(TextStyle(
            color: subColor,
            fontSize: _metaSize(17, scale),
            letterSpacing: _letter(0.3, scale),
            shadows: shadows,
          )),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxTextW);
    }

    // 4. 右下: 曝光参数 + 拍摄日期
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: _fontStyle(TextStyle(
          color: baseColor,
          fontSize: _metaSize(21, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: _letter(0.2, scale),
          shadows: shadows,
        )),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxTextW);

    TextPainter? dateP;
    if (showDetails && _meta.capturedDate.isNotEmpty) {
      final dateStr = _meta.capturedDate.length > 10
          ? _meta.capturedDate.substring(0, 10).replaceAll('-', '.')
          : _meta.capturedDate;
      dateP = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: _fontStyle(TextStyle(
            color: subColor,
            fontSize: _metaSize(15, scale),
            letterSpacing: _letter(0.3, scale),
            shadows: shadows,
          )),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxTextW);
    }

    // 5. 底部内侧两列底对齐排布
    final bottomY = size.height - padY;
    final leftBlockH = titleP.height + (lensP != null ? lineGap + lensP.height : 0);
    final rightBlockH = expoP.height + (dateP != null ? lineGap + dateP.height : 0);

    var leftY = bottomY - leftBlockH;
    _paintText(canvas, titleP, Offset(padX, leftY));
    if (lensP != null) {
      leftY += titleP.height + lineGap;
      _paintText(canvas, lensP, Offset(padX, leftY));
    }

    var rightY = bottomY - rightBlockH;
    _paintText(canvas, expoP, Offset(size.width - padX - expoP.width, rightY));
    if (dateP != null) {
      rightY += expoP.height + lineGap;
      _paintText(canvas, dateP, Offset(size.width - padX - dateP.width, rightY));
    }
  }

  /// 样式层注入所选字体与全局字重 (null/auto 保持原生)
  TextStyle _fontStyle(TextStyle style) {
    final fam = fontFamily;
    final weight = style.fontWeight == null ? null : _weight(style.fontWeight!);
    if (fam == null && weight == null) return style;
    return style.copyWith(fontFamily: fam, fontWeight: weight);
  }

  // =========================================================================
  // 模板 1: 高斯虚化 · 纯下边框 (Bottom Banner Blur)
  // 用户强推核心款：图片左右上无多余白边，仅带纯白下边框，周围全幅高斯虚化 + 悬浮阴影
  // 对标实拍设计: media_1791281238085.jpg, media_1791281238135.jpg, media_1791281248682.jpg
  // =========================================================================
  void _drawBottomBannerBlur(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    final cardFill = _cardFill(cardDark ? const Color(0xFF0C0D10) : Colors.white);
    final strongText = _textColor(textDark ? const Color(0xFF1E1E1E) : Colors.white);
    final mutedText = _secondaryTextColor(
        textDark ? const Color(0xFF757575) : const Color(0xFFB3B3B3));
    final bottomH = imgRect.height * 0.15 * spacingScale;
    final cardRect = Rect.fromLTRB(imgRect.left, imgRect.top, imgRect.right, imgRect.bottom + bottomH);
    final cardRadius = _cardRadius(scale);
    final cardRRect = RRect.fromRectAndRadius(cardRect, cardRadius);

    // 1. 周围全幅原图高斯虚化背景
    _drawGaussianBlurBackground(canvas, size, img, scale, tintOpacity: 0.24);

    // 2. 悬浮立体阴影
    _drawFloatingShadow(canvas, cardRRect, scale, isDark: _isEffectiveCardDark(cardDark ? const Color(0xFF0C0D10) : Colors.white));

    // 3. 悬浮卡片底层 (边框颜色黑白可选)
    canvas.drawRRect(cardRRect, Paint()..color = cardFill);

    // 4. 照片绘制 (图片左右上完全贴合卡片，顶部带匹配圆角裁切，底部无缝衔接下边框)
    final photoRRect = RRect.fromRectAndCorners(
      imgRect,
      topLeft: cardRadius,
      topRight: cardRadius,
    );
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale, clipRRect: photoRRect);

    // 微弱边框，防止纯白天空与白卡融色
    canvas.drawRRect(
      photoRRect,
      Paint()
        ..color = const Color(0x0A000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke(1.0, scale),
    );

    // 5. 纯下边框信息区 (尼康金标双行双列精致排版 + 大师参数)
    final paddingX = cardRect.left + 28 * scale;
    final rightMarginX = cardRect.right - 28 * scale;
    final line1Y = imgRect.bottom + bottomH * 0.38;
    final line2Y = line1Y + bottomH * 0.34 * lineSpacingScale;

    // 左侧第一行: 尼康金标亮色方标 + 相机型号
    final badgeW = 34 * scale;
    final badgeH = 20 * scale;
    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(paddingX, line1Y - badgeH * 0.75, badgeW, badgeH),
      Radius.circular(4 * scale),
    );
    canvas.drawRRect(badgeRRect, Paint()..color = accentColor);

    final badgeText = TextPainter(
      text: TextSpan(
        text: 'Nikon',
        style: TextStyle(
          color: _textColor(Colors.black),
          fontSize: _metaSize(10, scale),
          fontWeight: FontWeight.w900,
          letterSpacing: _letter(0.2, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeText.paint(
      canvas,
      Offset(
        paddingX + (badgeW - badgeText.width) / 2,
        line1Y - badgeH * 0.75 + (badgeH - badgeText.height) / 2,
      ),
    );

    final modelName = _meta.titleText.replaceAll(RegExp(r'^Nikon\s+', caseSensitive: false), '');
    final titleP = TextPainter(
      text: TextSpan(
        text: modelName.isNotEmpty ? modelName : _meta.titleText,
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(24, scale),
          fontWeight: FontWeight.w800,
          letterSpacing: _letter(0.5, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, titleP, Offset(paddingX + badgeW + 12 * scale, line1Y - titleP.height * 0.65));

    // 左侧第二行: 镜头型号
    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(14, scale),
            fontWeight: FontWeight.normal,
            letterSpacing: _letter(0.3, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, lensP, Offset(paddingX, line2Y - lensP.height * 0.5));
    }

    // 右侧第一行: 曝光四要素
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: TextStyle(
          color: strongText,
          fontSize: _metaSize(20, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: _letter(0.2, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, expoP, Offset(rightMarginX - expoP.width, line1Y - expoP.height * 0.65));

    // 右侧第二行: 拍摄时间与经纬度
    final dateGps = _dateAndGpsSubline();
    if (showDetails && dateGps.isNotEmpty) {
      final dateP = TextPainter(
        text: TextSpan(
          text: dateGps,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(14, scale),
            fontWeight: FontWeight.normal,
            letterSpacing: _letter(0.3, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, dateP, Offset(rightMarginX - dateP.width, line2Y - dateP.height * 0.5));
    }
  }

  String _dateAndGpsSubline() {
    final parts = <String>[];
    if (_meta.capturedDate.isNotEmpty) {
      parts.add(
        _meta.capturedDate.length > 10
            ? _meta.capturedDate.substring(0, 10).replaceAll('-', '.')
            : _meta.capturedDate,
      );
    }
    if (_meta.hasGps) {
      parts.add(_meta.gpsSummary);
    }
    return parts.join('  ·  ');
  }

  // =========================================================================
  // 模板 2: 高斯虚化 · 上下双边框 (Top Bottom Banner Blur)
  // 用户强推核心款：图片带精致上下留白边框，顶部艺术光影标，底部大师参数，周围全幅高斯虚化 + 阴影
  // 对标实拍设计: media_1791281238081.jpg, media_1791281238119.jpg
  // =========================================================================
  void _drawTopBottomBannerBlur(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    final cardFill = _cardFill(cardDark ? const Color(0xFF0C0D10) : const Color(0xFFF5F4F0));
    final strongText = _textColor(textDark ? const Color(0xFF1E1E1E) : Colors.white);
    final lensText = _secondaryTextColor(
        textDark ? const Color(0xFF757575) : Colors.white.withAlpha(165));
    final expoText = _textColor(
        textDark ? const Color(0xFF1E1E1E) : Colors.white.withAlpha(235));
    final dateText = _secondaryTextColor(
        textDark ? const Color(0xFF757575) : Colors.white.withAlpha(140));
    final topLabelText = _secondaryTextColor(
        textDark ? const Color(0xFF555555) : Colors.white.withAlpha(225));
    final topH = imgRect.height * 0.09 * spacingScale;
    final bottomH = imgRect.height * 0.15 * spacingScale;
    final cardRect = Rect.fromLTRB(imgRect.left, imgRect.top - topH, imgRect.right, imgRect.bottom + bottomH);
    final cardRadius = _cardRadius(scale);
    final cardRRect = RRect.fromRectAndRadius(cardRect, cardRadius);

    // 1. 周围全幅高斯虚化背景 (加深遮罩以衬托深邃黑金卡片)
    _drawGaussianBlurBackground(canvas, size, img, scale, tintOpacity: 0.38);

    // 2. 悬浮立体阴影
    _drawFloatingShadow(canvas, cardRRect, scale, isDark: _isEffectiveCardDark(cardDark ? const Color(0xFF0C0D10) : const Color(0xFFF5F4F0)));

    // 3. 悬浮卡片底板 (边框颜色黑白可选)
    canvas.drawRRect(cardRRect, Paint()..color = cardFill);

    // 4. 顶部艺术微标: "L I G H T   A N D   S H A D O W"
    final topCenterY = cardRect.top + topH / 2.0;
    final topP = TextPainter(
      text: TextSpan(
        text: 'L I G H T   A N D   S H A D O W',
        style: TextStyle(
          color: topLabelText,
          fontSize: _metaSize(13, scale),
          letterSpacing: _letter(6.5, scale),
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, topP, Offset(cardRect.left + (cardRect.width - topP.width) / 2, topCenterY - topP.height / 2));

    // 5. 居中照片 (左右与卡片边缘齐平)
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    // 6. 底部双行双列银白信息排版
    final paddingX = cardRect.left + 28 * scale;
    final rightMarginX = cardRect.right - 28 * scale;
    final line1Y = imgRect.bottom + bottomH * 0.38;
    final line2Y = line1Y + bottomH * 0.34 * lineSpacingScale;

    // 左侧第一行: 相机型号 (高反差加粗)
    final titleP = TextPainter(
      text: TextSpan(
        text: _meta.titleText,
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(22, scale),
          fontWeight: FontWeight.bold,
          letterSpacing: _letter(0.5, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, titleP, Offset(paddingX, line1Y - titleP.height * 0.65));

    // 左侧第二行: 镜头型号
    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: TextStyle(
            color: lensText,
            fontSize: _metaSize(13, scale),
            fontWeight: FontWeight.normal,
            letterSpacing: _letter(0.3, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, lensP, Offset(paddingX, line2Y - lensP.height * 0.5));
    }

    // 右侧第一行: 等宽曝光参数
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: TextStyle(
          color: expoText,
          fontSize: _metaSize(19, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
          letterSpacing: _letter(0.2, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, expoP, Offset(rightMarginX - expoP.width, line1Y - expoP.height * 0.65));

    // 右侧第二行: 拍摄时间
    if (showDetails && _meta.capturedDate.isNotEmpty) {
      final dateStr = _meta.capturedDate.length > 10 ? _meta.capturedDate.substring(0, 10).replaceAll('-', '.') : _meta.capturedDate;
      final dateP = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            color: dateText,
            fontSize: _metaSize(13, scale),
            fontWeight: FontWeight.normal,
            letterSpacing: _letter(0.3, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, dateP, Offset(rightMarginX - dateP.width, line2Y - dateP.height * 0.5));
    }
  }

  // =========================================================================
  // 模板 3: 高斯虚化 · 极光暗黑黑玻 (Dark Glass Blur)
  // 周围暗调虚化氛围 · 悬浮磨砂黑玻质感卡片 · 顶部微标与高反差银白参数
  // =========================================================================
  void _drawDarkGlassBlur(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    final cardFill = _cardFill(cardDark ? const Color(0xDE13151B) : const Color(0xFFF2F1ED));
    final cardStroke = cardFill.computeLuminance() < 0.45
        ? const Color(0x28FFFFFF)
        : const Color(0x22000000);
    final strongText = _textColor(textDark ? const Color(0xFF1B1D24) : Colors.white);
    final lensText = _secondaryTextColor(
        textDark ? const Color(0xFF757575) : Colors.white.withAlpha(150));
    final expoText = _textColor(
        textDark ? const Color(0xFF1E1E1E) : Colors.white.withAlpha(230));
    final dateText = _secondaryTextColor(
        textDark ? const Color(0xFF757575) : Colors.white.withAlpha(130));
    final topH = imgRect.height * 0.05 * spacingScale;
    final bottomH = imgRect.height * 0.15 * spacingScale;
    final cardRect = Rect.fromLTRB(imgRect.left, imgRect.top - topH, imgRect.right, imgRect.bottom + bottomH);
    final cardRRect = RRect.fromRectAndRadius(cardRect, _cardRadius(scale));

    // 1. 周围暗调高斯虚化
    _drawGaussianBlurBackground(canvas, size, img, scale, tintOpacity: 0.45);

    // 2. 悬浮立体阴影
    _drawFloatingShadow(canvas, cardRRect, scale, isDark: _isEffectiveCardDark(cardDark ? const Color(0xDE13151B) : const Color(0xFFF2F1ED)));

    // 3. 悬浮磨砂底板 + 微光高光边框 (边框颜色黑白可选)
    canvas.drawRRect(cardRRect, Paint()..color = cardFill);
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..color = cardStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke(1.2, scale),
    );

    // 4. 居中照片
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    // 5. 底部信息排版
    final paddingX = cardRect.left + 26 * scale;
    final rightMarginX = cardRect.right - 26 * scale;
    final line1Y = imgRect.bottom + bottomH * 0.38;
    final line2Y = imgRect.bottom + bottomH * 0.72;

    // 左侧第一行: 尼康金标方标 + 相机型号
    final badgeW = 32 * scale;
    final badgeH = 18 * scale;
    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(paddingX, line1Y - badgeH * 0.75, badgeW, badgeH),
      Radius.circular(3 * scale),
    );
    canvas.drawRRect(badgeRRect, Paint()..color = accentColor);

    final badgeText = TextPainter(
      text: TextSpan(
        text: 'Nikon',
        style: TextStyle(
          color: _textColor(Colors.black),
          fontSize: _metaSize(9.5, scale),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeText.paint(
      canvas,
      Offset(paddingX + (badgeW - badgeText.width) / 2, line1Y - badgeH * 0.75 + (badgeH - badgeText.height) / 2),
    );

    final modelName = _meta.titleText.replaceAll(RegExp(r'^Nikon\s+', caseSensitive: false), '');
    final titleP = TextPainter(
      text: TextSpan(
        text: modelName.isNotEmpty ? modelName : _meta.titleText,
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(22, scale),
          fontWeight: FontWeight.bold,
          letterSpacing: _letter(0.5, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, titleP, Offset(paddingX + badgeW + 10 * scale, line1Y - titleP.height * 0.65));

    // 左侧第二行: 镜头型号
    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: TextStyle(
            color: lensText,
            fontSize: _metaSize(13, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, lensP, Offset(paddingX, line2Y - lensP.height * 0.5));
    }

    // 右侧第一行: 曝光参数
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: TextStyle(
          color: expoText,
          fontSize: _metaSize(19, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, expoP, Offset(rightMarginX - expoP.width, line1Y - expoP.height * 0.65));

    // 右侧第二行: 拍摄时间
    if (showDetails && _meta.capturedDate.isNotEmpty) {
      final dateStr = _meta.capturedDate.length > 10 ? _meta.capturedDate.substring(0, 10).replaceAll('-', '.') : _meta.capturedDate;
      final dateP = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            color: dateText,
            fontSize: _metaSize(13, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, dateP, Offset(rightMarginX - dateP.width, line2Y - dateP.height * 0.5));
    }
  }

  // =========================================================================
  // 模板 4: 高斯虚化 · 拍立得相纸 (Polaroid Blur)
  // 周围全幅高斯虚化 · 浮动复古白卡立体相纸 · 四周留白与经典宽厚底标
  // =========================================================================
  void _drawPolaroidBlur(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    final cardFill = _cardFill(cardDark ? const Color(0xFF17181C) : const Color(0xFFFAF9F6));
    final strongText = _textColor(
        textDark ? const Color(0xFF2B2B2B) : const Color(0xFFF0F0F0));
    final mutedText = _secondaryTextColor(
        textDark ? const Color(0xFF7A7A7A) : const Color(0xFFAAAAAA));
    final expoText = _textColor(
        textDark ? const Color(0xFF333333) : const Color(0xFFEDEDED));
    final photoStroke = cardFill.computeLuminance() < 0.45
        ? const Color(0x18FFFFFF)
        : const Color(0x0F000000);
    final pad = imgRect.width * 0.032 * spacingScale;
    final bottomH = imgRect.height * 0.16 * spacingScale;
    final cardRect = Rect.fromLTRB(imgRect.left - pad, imgRect.top - pad, imgRect.right + pad, imgRect.bottom + bottomH);
    final cardRRect = RRect.fromRectAndRadius(cardRect, _cardRadius(scale, 8));

    // 1. 周围全幅高斯虚化背景
    _drawGaussianBlurBackground(canvas, size, img, scale, tintOpacity: 0.22);

    // 2. 悬浮真实纸质阴影
    _drawFloatingShadow(canvas, cardRRect, scale, isDark: _isEffectiveCardDark(cardDark ? const Color(0xFF17181C) : const Color(0xFFFAF9F6)));

    // 3. 相纸底层 (边框颜色黑白可选)
    canvas.drawRRect(cardRRect, Paint()..color = cardFill);

    // 4. 照片居中放置
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    // 微弱边框，衬托相纸反差
    canvas.drawRect(
      imgRect,
      Paint()
        ..color = photoStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke(1.0, scale),
    );

    // 5. 拍立得宽厚底边信息栏
    final paddingX = cardRect.left + 24 * scale;
    final rightMarginX = cardRect.right - 24 * scale;
    final line1Y = imgRect.bottom + bottomH * 0.40;
    final line2Y = line1Y + bottomH * 0.32 * lineSpacingScale;

    // 左侧第一行: 机型型号
    final titleP = TextPainter(
      text: TextSpan(
        text: _meta.titleText,
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(22, scale),
          fontWeight: FontWeight.bold,
          letterSpacing: _letter(0.5, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, titleP, Offset(paddingX, line1Y - titleP.height * 0.65));

    // 左侧第二行: 镜头
    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(13, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, lensP, Offset(paddingX, line2Y - lensP.height * 0.5));
    }

    // 右侧第一行: 曝光参数
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: TextStyle(
          color: expoText,
          fontSize: _metaSize(18, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, expoP, Offset(rightMarginX - expoP.width, line1Y - expoP.height * 0.65));

    // 右侧第二行: 时间
    if (showDetails && _meta.capturedDate.isNotEmpty) {
      final dateStr = _meta.capturedDate.length > 10 ? _meta.capturedDate.substring(0, 10).replaceAll('-', '.') : _meta.capturedDate;
      final dateP = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(13, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, dateP, Offset(rightMarginX - dateP.width, line2Y - dateP.height * 0.5));
    }
  }

  // =========================================================================
  // 模板 5: 大师画廊 · 纯净直出底栏 (Flush Master Bar)
  // 满幅照片直接拼接 · 无周围虚化背景 · 底部追加德味大师信息条 · 保留照片最大展示面积
  // =========================================================================
  void _drawFlushMasterBar(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    final barFill = _cardFill(cardDark ? const Color(0xFF0E0F12) : Colors.white);
    final strongText = _textColor(textDark ? const Color(0xFF111111) : Colors.white);
    final divColor = _secondaryTextColor(
        textDark ? const Color(0xFFCCCCCC) : const Color(0xFF444444));
    final lensColor = _secondaryTextColor(
        textDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA));

    // 1. 照片直出满幅填充
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    // 2. 底部大师底栏 (边框颜色黑白可选)
    final bottomTop = imgRect.bottom;
    final bottomH = size.height - bottomTop;
    final padding = 32 * scale;

    canvas.drawRect(Rect.fromLTWH(0, bottomTop, size.width, bottomH), Paint()..color = barFill);

    final centerY = bottomTop + bottomH / 2.0;

    // 左侧: 经典尼康金标印记圆标 + 机型
    final badgeRadius = 14 * scale;
    final badgePaint = Paint()..color = accentColor;
    canvas.drawCircle(Offset(padding + badgeRadius, centerY), badgeRadius, badgePaint);

    final badgeText = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
            color: _textColor(Colors.black),
            fontSize: _metaSize(13, scale),
            fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, badgeText, Offset(padding + badgeRadius - badgeText.width / 2, centerY - badgeText.height / 2));

    final titleP = TextPainter(
      text: TextSpan(
        text: _meta.titleText,
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(22, scale),
          fontWeight: FontWeight.w900,
          letterSpacing: _letter(0.5, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final titleX = padding + badgeRadius * 2 + 12 * scale;
    _paintText(canvas, titleP, Offset(titleX, centerY - titleP.height / 2));

    // 中间细分割竖线
    final divX = titleX + titleP.width + 24 * scale;
    final divPaint = Paint()
      ..color = divColor
      ..strokeWidth = _stroke(1.5, scale);
    canvas.drawLine(Offset(divX, centerY - 14 * scale), Offset(divX, centerY + 14 * scale), divPaint);

    // 镜头名称
    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: TextStyle(
            color: lensColor,
            fontSize: _metaSize(16, scale),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, lensP, Offset(divX + 20 * scale, centerY - lensP.height / 2));
    }

    // 右侧: 等宽曝光参数
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: TextStyle(
          color: strongText,
          fontSize: _metaSize(20, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(canvas, expoP, Offset(size.width - padding - expoP.width, centerY - expoP.height / 2));
  }


  // =========================================================================
  // 新模板 1: 杂志封面 (Magazine Cover)
  // =========================================================================
  void _drawMagazineCover(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    final cardFill = _cardFill(cardDark ? const Color(0xFF101216) : const Color(0xFFF6F3EC));
    final strongText = _textColor(
        textDark ? const Color(0xFF15161A) : Colors.white);
    final mutedText = _secondaryTextColor(
        textDark ? const Color(0xFF6B6B6B) : Colors.white70);
    final topH = imgRect.height * 0.11 * spacingScale;
    final bottomH = imgRect.height * 0.13 * spacingScale;
    final cardRect = Rect.fromLTRB(
        imgRect.left, imgRect.top - topH, imgRect.right, imgRect.bottom + bottomH);
    final cardRRect = RRect.fromRectAndRadius(cardRect, _cardRadius(scale, 14));

    _drawGaussianBlurBackground(canvas, size, img, scale, tintOpacity: 0.30);
    _drawFloatingShadow(canvas, cardRRect, scale, isDark: _isEffectiveCardDark(cardDark ? const Color(0xFF101216) : const Color(0xFFF6F3EC)));
    canvas.drawRRect(cardRRect, Paint()..color = cardFill);
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final padX = imgRect.left + 30 * scale;
    final rightX = imgRect.right - 30 * scale;

    // 顶部：大标题 + 强调色分割线
    final titleP = TextPainter(
      text: TextSpan(
        text: _meta.titleText,
        style: TextStyle(
            color: strongText,
            fontSize: _titleSize(30, scale),
            fontWeight: FontWeight.w900,
            letterSpacing: _letter(1.2, scale)),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: imgRect.width - 60 * scale);
    _paintText(canvas, titleP, Offset(padX, imgRect.top - topH * 0.72));

    canvas.drawRect(
      Rect.fromLTWH(padX, imgRect.top - topH * 0.24, imgRect.width * 0.22, 3 * scale),
      Paint()..color = accentColor,
    );

    // 底部左：镜头 / 右：曝光 + 日期
    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
            text: _meta.lensModel,
            style: TextStyle(
                color: mutedText,
                fontSize: _metaSize(14, scale),
                letterSpacing: _letter(0.3, scale))),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imgRect.width * 0.5);
      _paintText(canvas, lensP, Offset(padX, imgRect.bottom + bottomH * 0.34));
    }
    if (_meta.exposureSummary.isNotEmpty) {
      final expoP = TextPainter(
        text: TextSpan(
            text: _meta.exposureSummary,
            style: TextStyle(
                color: strongText,
                fontSize: _metaSize(17, scale),
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imgRect.width * 0.55);
      _paintText(canvas, expoP, Offset(rightX - expoP.width, imgRect.bottom + bottomH * 0.28));
    }
    if (_meta.capturedDate.isNotEmpty) {
      final dateP = TextPainter(
        text: TextSpan(
            text: _meta.capturedDate,
            style: TextStyle(
                color: mutedText,
                fontSize: _metaSize(12, scale),
                letterSpacing: _letter(0.4, scale))),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, dateP, Offset(rightX - dateP.width, imgRect.bottom + bottomH * 0.58));
    }
  }

  // =========================================================================
  // 新模板 3: 渐变字幕 (Gradient Caption)
  // =========================================================================
  void _drawGradientCaption(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    // 底部渐变遮罩（沉浸式压底，无实体边框；边框色映射为渐变基色）
    final maskH = imgRect.height * 0.42;
    final maskRect = Rect.fromLTWH(0, imgRect.bottom - maskH, imgRect.width, maskH);
    final maskColor = _cardFill(const Color(0xFF000000));
    canvas.drawRect(
      maskRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, maskRect.top),
          Offset(0, maskRect.bottom),
          [
            Colors.transparent,
            maskColor.withAlpha(204),
            maskColor.withAlpha(238),
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    final padX = 44 * scale;
    final baseline = imgRect.bottom - 40 * scale;

    if (_meta.titleText.isNotEmpty) {
      final titleP = TextPainter(
        text: TextSpan(
            text: _meta.titleText,
            style: TextStyle(
                color: _textColor(Colors.white),
                fontSize: _titleSize(32, scale),
                fontWeight: FontWeight.w900,
                letterSpacing: _letter(1.4, scale))),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imgRect.width * 0.72);
      _paintText(canvas, titleP, Offset(padX, baseline - titleP.height * 2.0));
    }

    // 强调色短横线
    canvas.drawRect(
      Rect.fromLTWH(padX, baseline - 12 * scale, 56 * scale, 3 * scale),
      Paint()..color = accentColor,
    );

    if (_meta.exposureSummary.isNotEmpty) {
      final expoP = TextPainter(
        text: TextSpan(
            text: _meta.exposureSummary,
            style: TextStyle(
                color: _secondaryTextColor(Colors.white.withAlpha(225)),
                fontSize: _metaSize(15, scale),
                fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imgRect.width * 0.8);
      _paintText(canvas, expoP, Offset(padX, baseline));
    }
  }

  // =========================================================================
  // 新模板 4: 极简细线 (Minimal Line)
  // =========================================================================
  void _drawMinimalLine(Canvas canvas, Size size, ui.Image? img, Rect imgRect) {
    final scale = size.width / 1200.0;
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final lineColor = _cardFill(
      textDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    ).withAlpha(153);

    // 内嵌极细线框
    final inset = imgRect.width * 0.028;
    canvas.drawRect(
      Rect.fromLTRB(imgRect.left + inset, imgRect.top + inset,
          imgRect.right - inset, imgRect.bottom - inset),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke(1.2, scale)
        ..color = lineColor,
    );

    // 右下角极小参数（左上角强调色小方点）
    final padX = imgRect.right - inset - 16 * scale;
    var bottom = imgRect.bottom - inset - 18 * scale;

    if (_meta.exposureSummary.isNotEmpty) {
      final expoP = TextPainter(
        text: TextSpan(
            text: _meta.exposureSummary,
            style: TextStyle(
                color: _textColor(Colors.white),
                fontSize: _metaSize(13, scale),
                fontFamily: 'monospace',
                shadows: [Shadow(color: _textShadowColor(const Color(0xAA000000)), blurRadius: 6)]),
            ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, expoP, Offset(padX - expoP.width, bottom));
      bottom -= expoP.height + 6 * scale;
    }
    if (_meta.cameraModel.isNotEmpty) {
      final modelP = TextPainter(
        text: TextSpan(
            text: _meta.cameraModel,
            style: TextStyle(
                color: _secondaryTextColor(Colors.white70),
                fontSize: _metaSize(11, scale),
                letterSpacing: _letter(0.6, scale),
                shadows: [Shadow(color: _textShadowColor(const Color(0xAA000000)), blurRadius: 6)])),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintText(canvas, modelP, Offset(padX - modelP.width, bottom));
    }
    canvas.drawRect(
      Rect.fromLTWH(imgRect.left + inset + 16 * scale, imgRect.bottom - inset - 18 * scale,
          18 * scale, 3 * scale),
      Paint()..color = accentColor,
    );
  }

  // =========================================================================
  // 开源致敬模板 1: 经典白边 · 品牌框 (Brand Classic White — Copicseal / PicSeal)
  // =========================================================================
  void _drawBrandClassicWhite(
    Canvas canvas,
    Size size,
    ui.Image? img,
    Rect imgRect,
  ) {
    final scale = size.width / 1200.0;
    final bgFill = _cardFill(cardDark ? const Color(0xFF101216) : Colors.white);
    final strongText = _textColor(
      textDark ? const Color(0xFF18191C) : Colors.white,
    );
    final mutedText = _secondaryTextColor(
      textDark ? const Color(0xFF6E7178) : Colors.white70,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgFill,
    );
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final bottomTop = imgRect.bottom;
    final bottomH = size.height - bottomTop;
    final centerY = bottomTop + bottomH * 0.5;
    final padX = 40 * scale;

    // 左侧：机型 + 镜头
    final modelP = TextPainter(
      text: TextSpan(
        text: _meta.titleText.isNotEmpty ? _meta.titleText : 'CAMERA',
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(24, scale),
          fontWeight: FontWeight.w800,
          letterSpacing: _letter(0.5, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width * 0.42);

    if (_meta.lensModel.isNotEmpty) {
      final lensP = TextPainter(
        text: TextSpan(
          text: _meta.lensModel,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(14, scale),
            letterSpacing: _letter(0.2, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width * 0.42);
      final gap = _line(5, scale);
      final totalLeftH = modelP.height + gap + lensP.height;
      _paintText(canvas, modelP, Offset(padX, centerY - totalLeftH / 2));
      _paintText(
        canvas,
        lensP,
        Offset(padX, centerY - totalLeftH / 2 + modelP.height + gap),
      );
    } else {
      _paintText(canvas, modelP, Offset(padX, centerY - modelP.height / 2));
    }

    // 右侧：曝光参数 + 时间/经纬度 + 竖线分隔 + 自动识别相机品牌矢量徽标
    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary,
        style: TextStyle(
          color: strongText,
          fontSize: _metaSize(19, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: _letter(0.2, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width * 0.44);

    final subLine = _dateAndGpsSubline();
    TextPainter? subP;
    if (subLine.isNotEmpty) {
      subP = TextPainter(
        text: TextSpan(
          text: subLine,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(13, scale),
            letterSpacing: _letter(0.2, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width * 0.44);
    }

    final rightEdge = size.width - padX;
    final gap = _line(5, scale);
    final rightBlockH = expoP.height + (subP != null ? gap + subP.height : 0);
    final rightBlockW = math.max(expoP.width, subP?.width ?? 0.0);

    _paintText(
      canvas,
      expoP,
      Offset(rightEdge - expoP.width, centerY - rightBlockH / 2),
    );
    if (subP != null) {
      _paintText(
        canvas,
        subP,
        Offset(
          rightEdge - subP.width,
          centerY - rightBlockH / 2 + expoP.height + gap,
        ),
      );
    }

    if (showBrandLogo) {
      final divX = rightEdge - rightBlockW - 22 * scale;
      canvas.drawLine(
        Offset(divX, centerY - bottomH * 0.24),
        Offset(divX, centerY + bottomH * 0.24),
        Paint()
          ..color = mutedText.withValues(alpha: 0.38)
          ..strokeWidth = _stroke(1.4, scale),
      );
      final logoH = bottomH * 0.46;
      final logoSize = CameraBrandEmblem.measure(metadata, height: logoH);
      final logoRect = Rect.fromLTWH(
        divX - 20 * scale - logoSize.width,
        centerY - logoH / 2,
        logoSize.width,
        logoH,
      );
      CameraBrandEmblem.paint(
        canvas,
        logoRect,
        metadata,
        textColor: strongText,
        accentColor: accentColor,
      );
    }
  }

  // =========================================================================
  // 开源致敬模板 2: 徽标居中 · 展签框 (Brand Emblem Center — semi-utils)
  // =========================================================================
  void _drawBrandEmblemCenter(
    Canvas canvas,
    Size size,
    ui.Image? img,
    Rect imgRect,
  ) {
    final scale = size.width / 1200.0;
    final bgFill = _cardFill(
      cardDark ? const Color(0xFF101216) : const Color(0xFFFAF9F5),
    );
    final strongText = _textColor(
      textDark ? const Color(0xFF18191C) : Colors.white,
    );
    final mutedText = _secondaryTextColor(
      textDark ? const Color(0xFF6B6E75) : Colors.white70,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgFill,
    );
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final bottomTop = imgRect.bottom;
    final bottomH = size.height - bottomTop;
    final cx = size.width / 2;
    var cursorY = bottomTop + bottomH * 0.16;

    if (showBrandLogo) {
      final logoH = bottomH * 0.30;
      final logoSize = CameraBrandEmblem.measure(metadata, height: logoH);
      final logoRect = Rect.fromLTWH(
        cx - logoSize.width / 2,
        cursorY,
        logoSize.width,
        logoH,
      );
      CameraBrandEmblem.paint(
        canvas,
        logoRect,
        metadata,
        textColor: strongText,
        accentColor: accentColor,
      );
      cursorY += logoH + _line(8, scale);
    }

    if (_meta.exposureSummary.isNotEmpty) {
      final expoP = TextPainter(
        text: TextSpan(
          text: _meta.exposureSummary,
          style: TextStyle(
            color: strongText,
            fontSize: _metaSize(18, scale),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            letterSpacing: _letter(0.4, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.85);
      _paintText(canvas, expoP, Offset(cx - expoP.width / 2, cursorY));
      cursorY += expoP.height + _line(6, scale);
    }

    final subParts = <String>[
      if (_meta.cameraModel.isNotEmpty) _meta.titleText,
      if (_meta.lensModel.isNotEmpty) _meta.lensModel,
      if (_meta.hasGps) _meta.gpsSummary,
      if (_meta.capturedDate.isNotEmpty && !_meta.hasGps) _meta.capturedDate,
    ];
    if (subParts.isNotEmpty) {
      final subP = TextPainter(
        text: TextSpan(
          text: subParts.join('  ·  '),
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(13, scale),
            letterSpacing: _letter(0.3, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width * 0.86);
      _paintText(canvas, subP, Offset(cx - subP.width / 2, cursorY));
    }
  }

  // =========================================================================
  // 开源致敬模板 3: 圆角阴影 · 品牌悬浮 (Blur Floating Shadow — semi-utils / camera-watermark)
  // =========================================================================
  void _drawBlurFloatingShadow(
    Canvas canvas,
    Size size,
    ui.Image? img,
    Rect imgRect,
  ) {
    final scale = size.width / 1200.0;
    final strongText = _textColor(
      textDark ? const Color(0xFF18191C) : Colors.white,
    );
    final mutedText = _secondaryTextColor(
      textDark ? const Color(0xFF55585E) : Colors.white.withAlpha(210),
    );
    final shadows = [
      Shadow(
        color: _textShadowColor(const Color(0xAA000000)),
        offset: Offset(0, 2 * scale),
        blurRadius: 8 * scale,
      ),
    ];

    // 1. 全幅高斯模糊背景
    _drawGaussianBlurBackground(canvas, size, img, scale, tintOpacity: 0.34);

    // 2. 原图圆角立体投影（无多余衬底卡，照片本身悬浮）
    final photoRadius = _cardRadius(scale, 22);
    final photoRRect = RRect.fromRectAndRadius(imgRect, photoRadius);
    _drawFloatingShadow(canvas, photoRRect, scale, isDark: true);
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale, clipRRect: photoRRect);

    // 3. 底部模糊区中央悬浮相机品牌徽标 + 曝光参数 + 经纬度
    final bottomTop = imgRect.bottom;
    final bottomH = size.height - bottomTop;
    final cx = size.width / 2;
    var cursorY = bottomTop + bottomH * 0.16;

    if (showBrandLogo) {
      final logoH = bottomH * 0.30;
      final logoSize = CameraBrandEmblem.measure(metadata, height: logoH);
      CameraBrandEmblem.paint(
        canvas,
        Rect.fromLTWH(cx - logoSize.width / 2, cursorY, logoSize.width, logoH),
        metadata,
        textColor: strongText,
        accentColor: accentColor,
      );
      cursorY += logoH + _line(6, scale);
    }

    if (_meta.exposureSummary.isNotEmpty) {
      final expoP = TextPainter(
        text: TextSpan(
          text: _meta.exposureSummary,
          style: TextStyle(
            color: strongText,
            fontSize: _metaSize(19, scale),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            letterSpacing: _letter(0.4, scale),
            shadows: shadows,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.85);
      _paintText(canvas, expoP, Offset(cx - expoP.width / 2, cursorY));
      cursorY += expoP.height + _line(5, scale);
    }

    final subParts = <String>[
      if (_meta.cameraModel.isNotEmpty) _meta.titleText,
      if (_meta.lensModel.isNotEmpty) _meta.lensModel,
      if (_meta.hasGps) _meta.gpsSummary,
    ];
    if (subParts.isNotEmpty) {
      final subP = TextPainter(
        text: TextSpan(
          text: subParts.join('  ·  '),
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(13, scale),
            letterSpacing: _letter(0.3, scale),
            shadows: shadows,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width * 0.85);
      _paintText(canvas, subP, Offset(cx - subP.width / 2, cursorY));
    }
  }

  // =========================================================================
  // 开源致敬模板 4: 右下角 · 极简参数 (Minimal Corner Param — semi-utils)
  // =========================================================================
  void _drawMinimalCornerParam(
    Canvas canvas,
    Size size,
    ui.Image? img,
    Rect imgRect,
  ) {
    final scale = size.width / 1200.0;
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final pillBg = _cardFill(
      cardDark ? const Color(0xCC0E1116) : const Color(0xD8FFFFFF),
    );
    final strongText = _textColor(
      textDark ? const Color(0xFF18191C) : Colors.white,
    );
    final mutedText = _secondaryTextColor(
      textDark ? const Color(0xFF5A5D64) : Colors.white70,
    );

    final expoP = TextPainter(
      text: TextSpan(
        text: _meta.exposureSummary.isNotEmpty
            ? _meta.exposureSummary
            : _meta.titleText,
        style: TextStyle(
          color: strongText,
          fontSize: _metaSize(16, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width * 0.52);

    final secondLine = <String>[
      if (_meta.cameraModel.isNotEmpty) _meta.titleText,
      if (_meta.hasGps) _meta.gpsSummary,
    ].join(' · ');

    TextPainter? subP;
    if (secondLine.isNotEmpty) {
      subP = TextPainter(
        text: TextSpan(
          text: secondLine,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(12, scale),
            letterSpacing: _letter(0.2, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width * 0.52);
    }

    final textBlockW = math.max(expoP.width, subP?.width ?? 0.0);
    final textBlockH =
        expoP.height + (subP != null ? 4 * scale + subP.height : 0.0);
    final logoH = 28 * scale;
    final logoSize = showBrandLogo
        ? CameraBrandEmblem.measure(metadata, height: logoH)
        : Size.zero;

    final padH = 20 * scale;
    final padV = 14 * scale;
    final innerW = textBlockW +
        (showBrandLogo ? logoSize.width + 24 * scale : 0.0);
    final pillW = innerW + padH * 2;
    final pillH = math.max(textBlockH, logoH) + padV * 2;

    final margin = 28 * scale * spacingScale;
    final pillRect = Rect.fromLTWH(
      imgRect.right - margin - pillW,
      imgRect.bottom - margin - pillH,
      pillW,
      pillH,
    );
    final pillRRect = RRect.fromRectAndRadius(
      pillRect,
      _cardRadius(scale, 14),
    );
    canvas.drawRRect(pillRRect, Paint()..color = pillBg);
    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = strongText.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke(1.0, scale),
    );

    var curX = pillRect.left + padH;
    final cy = pillRect.center.dy;
    if (showBrandLogo) {
      CameraBrandEmblem.paint(
        canvas,
        Rect.fromLTWH(curX, cy - logoH / 2, logoSize.width, logoH),
        metadata,
        textColor: strongText,
        accentColor: accentColor,
      );
      curX += logoSize.width + 12 * scale;
      canvas.drawLine(
        Offset(curX, cy - pillH * 0.26),
        Offset(curX, cy + pillH * 0.26),
        Paint()
          ..color = accentColor
          ..strokeWidth = _stroke(1.6, scale),
      );
      curX += 12 * scale;
    }

    _paintText(canvas, expoP, Offset(curX, cy - textBlockH / 2));
    if (subP != null) {
      _paintText(
        canvas,
        subP,
        Offset(curX, cy - textBlockH / 2 + expoP.height + 4 * scale),
      );
    }
  }

  // =========================================================================
  // 开源致敬模板 5: 复古胶片 · 日期戳 (Retro Timestamp — Copicseal)
  // =========================================================================
  void _drawRetroTimestamp(
    Canvas canvas,
    Size size,
    ui.Image? img,
    Rect imgRect,
  ) {
    final scale = size.width / 1200.0;
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final stampOrange = textColorOverride ?? const Color(0xFFFF7A1A);
    final glowColor = const Color(0xCCFF3D00);
    final marginX = 42 * scale * spacingScale;
    final marginY = 36 * scale * spacingScale;

    final rawDate = _meta.capturedDate.isNotEmpty
        ? _meta.capturedDate
        : '2026.10.26 14:32';
    final formattedStamp = "'${rawDate.replaceAll('.', ' ').replaceAll('-', ' ')}";

    final stampP = TextPainter(
      text: TextSpan(
        text: formattedStamp,
        style: TextStyle(
          color: stampOrange,
          fontSize: _titleSize(28, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          letterSpacing: _letter(2.2, scale),
          shadows: [
            Shadow(color: glowColor, blurRadius: 12 * scale),
            Shadow(color: const Color(0x99000000), blurRadius: 4 * scale),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _paintText(
      canvas,
      stampP,
      Offset(
        imgRect.right - marginX - stampP.width,
        imgRect.bottom - marginY - stampP.height,
      ),
    );

    // 左下角胶片帧号 + 机型 + 经纬度
    final leftInfo = <String>[
      '◀ 36A',
      if (_meta.cameraModel.isNotEmpty) _meta.titleText,
      if (_meta.exposureSummary.isNotEmpty) _meta.exposureSummary,
      if (_meta.hasGps) _meta.gpsSummary,
    ].join('   ');
    final leftP = TextPainter(
      text: TextSpan(
        text: leftInfo,
        style: TextStyle(
          color: stampOrange.withValues(alpha: 0.88),
          fontSize: _metaSize(14, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          letterSpacing: _letter(0.8, scale),
          shadows: [
            Shadow(color: glowColor, blurRadius: 8 * scale),
            Shadow(color: const Color(0xAA000000), blurRadius: 4 * scale),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width * 0.56);

    _paintText(
      canvas,
      leftP,
      Offset(imgRect.left + marginX, imgRect.bottom - marginY - leftP.height),
    );
  }

  // =========================================================================
  // 开源致敬模板 6: 地理坐标 · 经纬度展签 (Geo Location Editorial)
  // =========================================================================
  void _drawGeoLocationEditorial(
    Canvas canvas,
    Size size,
    ui.Image? img,
    Rect imgRect,
  ) {
    final scale = size.width / 1200.0;
    final bgFill = _cardFill(
      cardDark ? const Color(0xFF0E1014) : const Color(0xFFF9F8F4),
    );
    final strongText = _textColor(
      textDark ? const Color(0xFF16181D) : Colors.white,
    );
    final mutedText = _secondaryTextColor(
      textDark ? const Color(0xFF686B73) : Colors.white70,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgFill,
    );
    _drawPhotoOrPlaceholder(canvas, img, imgRect, scale);

    final bottomTop = imgRect.bottom;
    final bottomH = size.height - bottomTop;
    final cy = bottomTop + bottomH * 0.5;
    final leftX = imgRect.left + 12 * scale;
    final rightX = imgRect.right - 12 * scale;

    // 左侧：经纬度醒目胶囊角标 + DMS 坐标 + 曝光与镜头
    final gpsText = _meta.hasGps
        ? _meta.gpsSummary
        : (metadata.hasGps
            ? metadata.gpsSummary
            : 'GPS · 31°13\'49"N  121°28\'25"E');
    final altSuffix = (_meta.altitude != null && _meta.altitude != 0)
        ? '  ·  ALT ${_meta.altitude!.round()}m'
        : '';

    final badgeW = 46 * scale;
    final badgeH = 22 * scale;
    final line1Y = bottomTop + bottomH * 0.34;
    final line2Y = bottomTop + bottomH * 0.68;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(leftX, line1Y - badgeH / 2, badgeW, badgeH),
        Radius.circular(5 * scale),
      ),
      Paint()..color = accentColor,
    );
    final gpsTagP = TextPainter(
      text: TextSpan(
        text: 'GEO',
        style: TextStyle(
          color: Colors.black,
          fontSize: _metaSize(11, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w900,
          letterSpacing: _letter(0.8, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    gpsTagP.paint(
      canvas,
      Offset(
        leftX + (badgeW - gpsTagP.width) / 2,
        line1Y - gpsTagP.height / 2,
      ),
    );

    final coordP = TextPainter(
      text: TextSpan(
        text: '$gpsText$altSuffix',
        style: TextStyle(
          color: strongText,
          fontSize: _titleSize(21, scale),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          letterSpacing: _letter(0.4, scale),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: imgRect.width * 0.62);
    _paintText(
      canvas,
      coordP,
      Offset(leftX + badgeW + 12 * scale, line1Y - coordP.height / 2),
    );

    final subLeft = <String>[
      if (_meta.cameraModel.isNotEmpty) _meta.titleText,
      if (_meta.lensModel.isNotEmpty) _meta.lensModel,
      if (_meta.exposureSummary.isNotEmpty) _meta.exposureSummary,
      if (_meta.capturedDate.isNotEmpty) _meta.capturedDate,
    ].join('  ·  ');
    if (subLeft.isNotEmpty) {
      final subP = TextPainter(
        text: TextSpan(
          text: subLeft,
          style: TextStyle(
            color: mutedText,
            fontSize: _metaSize(14, scale),
            letterSpacing: _letter(0.2, scale),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imgRect.width * 0.68);
      _paintText(canvas, subP, Offset(leftX, line2Y - subP.height / 2));
    }

    if (showBrandLogo) {
      final logoH = bottomH * 0.44;
      final logoSize = CameraBrandEmblem.measure(metadata, height: logoH);
      CameraBrandEmblem.paint(
        canvas,
        Rect.fromLTWH(rightX - logoSize.width, cy - logoH / 2, logoSize.width, logoH),
        metadata,
        textColor: strongText,
        accentColor: accentColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WatermarkCanvasPainter old) {
    return old.image != image ||
           old.metadata != metadata ||
           old.template != template ||
           old.filterType != filterType ||
           old.filterIntensity != filterIntensity ||
           old.adjustments != adjustments ||
           old.spacingScale != spacingScale ||
           old.showDetails != showDetails ||
           old.cardDark != cardDark ||
           old.textDark != textDark ||
           old.cardColorOverride != cardColorOverride ||
           old.textColorOverride != textColorOverride ||
           old.titleTextScale != titleTextScale ||
           old.metaTextScale != metaTextScale ||
           old.letterSpacingScale != letterSpacingScale ||
           old.lineSpacingScale != lineSpacingScale ||
           old.fontWeight != fontWeight ||
           old.borderThicknessScale != borderThicknessScale ||
           old.fontFamily != fontFamily ||
           old.quarterTurns != quarterTurns ||
           old.mirrorX != mirrorX ||
           old.logoImage != logoImage ||
           old.logoScale != logoScale ||
           old.logoOpacity != logoOpacity ||
           old.customTextScale != customTextScale ||
           old.customLines.length != customLines.length ||
           !_sameLines(old.customLines, customLines) ||
           old.accentColor != accentColor ||
           old.cardTone != cardTone ||
           old.cornerRadiusFactor != cornerRadiusFactor ||
           old.showModel != showModel ||
           old.showLens != showLens ||
           old.showExposure != showExposure ||
           old.showDate != showDate ||
           old.showBrandLogo != showBrandLogo ||
           old.showGps != showGps ||
           old.watermarkOpacity != watermarkOpacity ||
           old.customTextAlign != customTextAlign ||
           old.logoCorner != logoCorner;
  }

  /// 统一文字绘制出口：用户选择字体/字重时覆盖，auto/null 保持模板原生样式。
  void _paintText(Canvas canvas, TextPainter tp, Offset at) {
    final span = tp.text;
    if (span is TextSpan) {
      final weight = span.style?.fontWeight == null
          ? null
          : _weight(span.style!.fontWeight!);
      if (fontFamily != null || weight != null) {
        tp.text = TextSpan(
          text: span.text,
          children: span.children,
          style: span.style?.copyWith(fontFamily: fontFamily, fontWeight: weight),
          recognizer: span.recognizer,
        );
        tp.layout();
      }
    }
    tp.paint(canvas, at);
  }
}
