import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/palette.dart';

/// Zync AI 功能专属矢量 SVG 图标集（纯矢量路径渲染，零 Emoji 字符）。
enum AiSvgIconKind {
  sparkleAperture,
  cropFrame,
  lightingSun,
  portraitPose,
  decisiveTiming,
  cameraPosition,
  lensFocal,
  masterFilter,
  filmRoll,
  presetSliders,
  cellularBypass,
  np3Chip,
  afTarget,
  openAiProtocol,
  anthropicProtocol,
  warningAlert,
  portraitRatio,
  landscapeRatio,
  compareOriginal,
  retryRefresh,
}

class AiSvgIcon extends StatelessWidget {
  final AiSvgIconKind kind;
  final double size;
  final Color? color;

  const AiSvgIcon(
    this.kind, {
    super.key,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? context.zc.textPrimary;
    return SvgPicture.string(
      _svgFor(kind),
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }

  static String _wrap(String body) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="#FFFFFF" stroke-width="1.85" '
      'stroke-linecap="round" stroke-linejoin="round">$body</svg>';

  static String _svgFor(AiSvgIconKind kind) => switch (kind) {
        AiSvgIconKind.sparkleAperture => _wrap(
            '<circle cx="11" cy="13" r="7.5"/>'
            '<path d="M11 5.5L13.6 10M17.5 9.2L12.8 11.4M17.5 16.8L12.4 14.6'
            'M11 20.5L8.4 16M4.5 16.8L9.2 14.6M4.5 9.2L9.6 11.4"/>'
            '<path d="M19 2.5V6.5M17 4.5H21" stroke-width="2"/>',
          ),
        AiSvgIconKind.cropFrame => _wrap(
            '<path d="M6.5 3V17.5H21"/>'
            '<path d="M3 6.5H17.5V21"/>'
            '<rect x="9.5" y="9.5" width="5" height="5" rx="1"/>',
          ),
        AiSvgIconKind.lightingSun => _wrap(
            '<circle cx="12" cy="12" r="4"/>'
            '<path d="M12 2.5V5M12 19V21.5M2.5 12H5M19 12H21.5'
            'M5.3 5.3L7.1 7.1M16.9 16.9L18.7 18.7'
            'M18.7 5.3L16.9 7.1M7.1 16.9L5.3 18.7"/>',
          ),
        AiSvgIconKind.portraitPose => _wrap(
            '<rect x="4" y="3" width="16" height="18" rx="2.5"/>'
            '<circle cx="12" cy="9.5" r="2.6"/>'
            '<path d="M7.5 18.5C8.3 15.8 10 14.5 12 14.5C14 14.5 15.7 15.8 16.5 18.5"/>',
          ),
        AiSvgIconKind.decisiveTiming => _wrap(
            '<circle cx="12" cy="13" r="7.5"/>'
            '<path d="M12 9V13.2L15 15"/>'
            '<path d="M9.5 3H14.5M12 3V5.5"/>',
          ),
        AiSvgIconKind.cameraPosition => _wrap(
            '<rect x="6.5" y="7.5" width="11" height="9" rx="2"/>'
            '<circle cx="12" cy="12" r="2.2"/>'
            '<path d="M12 2.5L10 4.5M12 2.5L14 4.5M12 2.5V6"/>'
            '<path d="M21.5 12L19.5 10M21.5 12L19.5 14M21.5 12H18.5"/>'
            '<path d="M2.5 12L4.5 10M2.5 12L4.5 14M2.5 12H5.5"/>',
          ),
        AiSvgIconKind.lensFocal => _wrap(
            '<circle cx="12" cy="12" r="8.5"/>'
            '<circle cx="12" cy="12" r="5"/>'
            '<circle cx="12" cy="12" r="1.8"/>'
            '<path d="M9.5 8.2L11 9.5"/>',
          ),
        AiSvgIconKind.masterFilter => _wrap(
            '<circle cx="9.5" cy="9.5" r="5"/>'
            '<circle cx="14.5" cy="9.5" r="5"/>'
            '<circle cx="12" cy="14.5" r="5"/>',
          ),
        AiSvgIconKind.filmRoll => _wrap(
            '<rect x="3" y="5" width="18" height="14" rx="2"/>'
            '<path d="M7 5V19M17 5V19M3 9H7M3 15H7M17 9H21M17 15H21"/>'
            '<circle cx="12" cy="12" r="2.3"/>',
          ),
        AiSvgIconKind.presetSliders => _wrap(
            '<path d="M4 7H20M4 12H20M4 17H20"/>'
            '<circle cx="9" cy="7" r="2" fill="#000000"/>'
            '<circle cx="15" cy="12" r="2" fill="#000000"/>'
            '<circle cx="10" cy="17" r="2" fill="#000000"/>',
          ),
        AiSvgIconKind.cellularBypass => _wrap(
            '<path d="M12 11.5V20"/>'
            '<circle cx="12" cy="9.5" r="1.7"/>'
            '<path d="M8.2 6.5A5.5 5.5 0 0 0 8.2 12.5M15.8 6.5A5.5 5.5 0 0 1 15.8 12.5"/>'
            '<path d="M5.4 3.8A9.5 9.5 0 0 0 5.4 15.2M18.6 3.8A9.5 9.5 0 0 1 18.6 15.2"/>',
          ),
        AiSvgIconKind.np3Chip => _wrap(
            '<rect x="4" y="4" width="16" height="16" rx="2.5"/>'
            '<path d="M7 16C9.5 16 10.5 8 17 8"/>'
            '<circle cx="16.5" cy="15.5" r="1.2"/>',
          ),
        AiSvgIconKind.afTarget => _wrap(
            '<path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8"/>'
            '<path d="M16 4H18.5A1.5 1.5 0 0 1 20 5.5V8"/>'
            '<path d="M4 16V18.5A1.5 1.5 0 0 0 5.5 20H8"/>'
            '<path d="M16 20H18.5A1.5 1.5 0 0 0 20 18.5V16"/>'
            '<circle cx="12" cy="12" r="2.5"/>',
          ),
        AiSvgIconKind.openAiProtocol => _wrap(
            '<polygon points="12,3 19.8,7.5 19.8,16.5 12,21 4.2,16.5 4.2,7.5"/>'
            '<circle cx="12" cy="12" r="3"/>',
          ),
        AiSvgIconKind.anthropicProtocol => _wrap(
            '<path d="M12 3.5L19.5 19.5H15.8L12 11L8.2 19.5H4.5L12 3.5Z"/>'
            '<path d="M8.5 15H15.5"/>',
          ),
        AiSvgIconKind.warningAlert => _wrap(
            '<path d="M12 3.5L21 19.5H3L12 3.5Z"/>'
            '<path d="M12 10V14"/>'
            '<circle cx="12" cy="16.8" r="0.8"/>',
          ),
        AiSvgIconKind.portraitRatio => _wrap(
            '<rect x="6.5" y="3" width="11" height="18" rx="2"/>'
            '<path d="M9.5 7.5H14.5M9.5 16.5H14.5"/>',
          ),
        AiSvgIconKind.landscapeRatio => _wrap(
            '<rect x="3" y="6.5" width="18" height="11" rx="2"/>'
            '<path d="M7.5 9.5V14.5M16.5 9.5V14.5"/>',
          ),
        AiSvgIconKind.compareOriginal => _wrap(
            '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/>'
            '<path d="M12 2.5V21.5"/>'
            '<path d="M8.5 12H6M15.5 12H18"/>',
          ),
        AiSvgIconKind.retryRefresh => _wrap(
            '<path d="M20 11A8 8 0 0 0 6.3 5.7L4 8"/>'
            '<path d="M4 4V8H8"/>'
            '<path d="M4 13A8 8 0 0 0 17.7 18.3L20 16"/>'
            '<path d="M20 20V16H16"/>',
          ),
      };
}
