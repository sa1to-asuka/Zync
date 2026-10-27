import 'package:flutter/material.dart';

import '../../engine/watermark/watermark_template.dart';
import '../design/design.dart';

/// 水印模板选择卡片（水印工坊与拼图水印页共用，避免重复实现）。
class WatermarkTemplateCard extends StatelessWidget {
  final WatermarkTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  const WatermarkTemplateCard({
    super.key,
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final t = template;
    return Material(
      color: ZSwatch.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? zc.accent.withAlpha(30) : zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(
              color: isSelected ? zc.accent : zc.outline,
              width: isSelected ? ZStroke.emphasis : ZStroke.hairline,
            ),
          ),
          child: Row(
            children: [
              _schematic(context, t, isSelected),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            t.trLabel,
                            style: TextStyle(
                              color: isSelected ? zc.accent : zc.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 11.5,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.check_circle,
                            size: 13,
                            color: zc.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        t.trDescription,
                        style: TextStyle(
                          color: zc.textTertiary,
                          fontSize: 9.5,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建水印模板排版结构线框缩略示意（供单列列表与多列网格共用）
  static Widget schematic(
    BuildContext context,
    WatermarkTemplate t,
    bool isSelected, {
    double width = 38,
    double height = 38,
  }) =>
      _schematic(context, t, isSelected, width: width, height: height);

  /// 构建水印模板排版结构线框缩略示意
  static Widget _schematic(
      BuildContext context, WatermarkTemplate t, bool isSelected,
      {double width = 38, double height = 38}) {
    final zc = context.zc;
    final accent = isSelected ? zc.accent : zc.textTertiary;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // 固定深底：线框代表模板真实配色，不随主题反转
        color: ZSwatch.wireframeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? zc.accent.withAlpha(140) : zc.outline,
          width: ZStroke.hairline,
        ),
      ),
      child: Center(
        child: _wireframe(context, t, accent),
      ),
    );
  }

  static Widget _wireframe(
      BuildContext context, WatermarkTemplate t, Color accent) {
    switch (t) {
      case WatermarkTemplate.none:
        return Icon(Icons.crop_free, size: 20, color: accent);
      case WatermarkTemplate.inPhotoOverlay:
        return Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: ZSwatch.wireframeOverlay,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 7, height: 2, color: accent),
                    Container(
                        width: 9, height: 2, color: accent.withAlpha(180)),
                  ],
                ),
              ),
            ],
          ),
        );
      case WatermarkTemplate.bottomBannerBlur:
        return Container(
          margin: const EdgeInsets.all(2),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: ZSwatch.wireframePhoto,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
              ),
              Container(
                height: 8,
                decoration: const BoxDecoration(
                  color: ZSwatch.pureWhite,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Container(width: 3, height: 3, color: ZSwatch.nikonGold),
                    const SizedBox(width: 2),
                    Container(width: 8, height: 2, color: ZSwatch.pureBlack),
                  ],
                ),
              ),
            ],
          ),
        );
      case WatermarkTemplate.topBottomBannerBlur:
        return Container(
          margin: const EdgeInsets.all(2),
          child: Column(
            children: [
              Container(height: 5, color: ZSwatch.pureWhite),
              Expanded(child: Container(color: ZSwatch.wireframePhoto)),
              Container(
                height: 7,
                color: ZSwatch.pureWhite,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Container(width: 8, height: 2, color: ZSwatch.pureBlack),
                  ],
                ),
              ),
            ],
          ),
        );
      case WatermarkTemplate.darkGlassBlur:
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ZSwatch.wireframeGlass,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: context.zc.textSecondary,
              width: 0.6,
            ),
          ),
          child: Column(
            children: [
              Expanded(child: Container(color: ZSwatch.wireframeGlassInner)),
              Container(
                height: 7,
                color: ZSwatch.wireframeGlassBar,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Container(width: 3, height: 3, color: ZSwatch.nikonGold),
                    const SizedBox(width: 2),
                    Container(width: 7, height: 1.5, color: ZSwatch.pureWhite),
                  ],
                ),
              ),
            ],
          ),
        );
      case WatermarkTemplate.polaroidBlur:
        return Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 7),
          decoration: BoxDecoration(
            color: ZSwatch.paperPolaroid,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Container(color: ZSwatch.wireframePhotoAlt),
        );
      case WatermarkTemplate.magazineCover:
        return Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
          decoration: BoxDecoration(
            color: ZSwatch.paperMagazine,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 16, height: 3, color: ZSwatch.black87),
              const SizedBox(height: 2),
              Container(width: 9, height: 1.5, color: accent),
              const SizedBox(height: 3),
              Expanded(child: Container(color: ZSwatch.wireframePhotoAlt)),
              const SizedBox(height: 3),
              Container(width: 12, height: 1.5, color: ZSwatch.black54),
            ],
          ),
        );
      case WatermarkTemplate.gradientCaption:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ZSwatch.wireframePhotoAlt, ZSwatch.wireframeGradBottom],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 16, height: 3, color: ZSwatch.pureWhite),
                  const SizedBox(height: 2),
                  Container(width: 6, height: 1.5, color: accent),
                ],
              ),
            ),
          ),
        );
      case WatermarkTemplate.minimalLine:
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ZSwatch.wireframePhotoAlt,
            border: Border.all(color: ZSwatch.white54, width: 0.6),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 1.5, color: ZSwatch.white70),
                  const SizedBox(width: 2),
                  Container(width: 4, height: 1.5, color: accent),
                ],
              ),
            ),
          ),
        );
      case WatermarkTemplate.flushMasterBar:
        return Container(
          margin: const EdgeInsets.all(2),
          child: Column(
            children: [
              Expanded(child: Container(color: ZSwatch.wireframePhoto)),
              Container(
                height: 8,
                color: ZSwatch.pureBlack,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: ZSwatch.nikonGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(width: 8, height: 2, color: ZSwatch.pureWhite),
                  ],
                ),
              ),
            ],
          ),
        );
      case WatermarkTemplate.brandClassicWhite:
        return Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
          decoration: BoxDecoration(
            color: ZSwatch.pureWhite,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            children: [
              Expanded(child: Container(color: ZSwatch.wireframePhotoAlt)),
              SizedBox(
                height: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 7, height: 2, color: ZSwatch.pureBlack),
                    Container(width: 3, height: 4, color: ZSwatch.nikonGold),
                    Container(width: 7, height: 1.5, color: ZSwatch.black54),
                  ],
                ),
              ),
            ],
          ),
        );
      case WatermarkTemplate.brandEmblemCenter:
        return Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
          decoration: BoxDecoration(
            color: ZSwatch.paperMagazine,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            children: [
              Expanded(child: Container(color: ZSwatch.wireframePhotoAlt)),
              const SizedBox(height: 1.5),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: ZSwatch.nikonGold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 1),
              Container(width: 12, height: 1.5, color: ZSwatch.black87),
            ],
          ),
        );
      case WatermarkTemplate.blurFloatingShadow:
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ZSwatch.wireframeGlass,
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ZSwatch.wireframePhoto,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(
                        color: ZSwatch.black54,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 3, height: 3, color: ZSwatch.nikonGold),
                  const SizedBox(width: 2),
                  Container(width: 10, height: 1.5, color: ZSwatch.pureWhite),
                ],
              ),
            ],
          ),
        );
      case WatermarkTemplate.minimalCornerParam:
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ZSwatch.wireframePhotoAlt,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(2.5),
              padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
              decoration: BoxDecoration(
                color: ZSwatch.black87,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 1.5, height: 5, color: ZSwatch.nikonGold),
                  const SizedBox(width: 2),
                  Container(width: 7, height: 2, color: ZSwatch.pureWhite),
                ],
              ),
            ),
          ),
        );
      case WatermarkTemplate.retroTimestamp:
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ZSwatch.wireframePhoto,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                "'98",
                style: TextStyle(
                  color: ZSwatch.fromArgb32(0xFFFF7A1A),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(
                      color: ZSwatch.fromArgb32(0xB4FF5500),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case WatermarkTemplate.geoLocationEditorial:
        return Container(
          margin: const EdgeInsets.all(2),
          child: Column(
            children: [
              Expanded(child: Container(color: ZSwatch.wireframePhoto)),
              Container(
                height: 9,
                color: ZSwatch.pureWhite,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.explore, size: 7, color: accent),
                    Container(width: 10, height: 2, color: ZSwatch.pureBlack),
                    Container(width: 4, height: 2, color: ZSwatch.nikonGold),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}
