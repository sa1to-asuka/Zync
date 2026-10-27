import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../engine/editor/photo_edit_controller.dart';
import '../../engine/editor/photo_edit_engine.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';

/// 编辑工具类型（编辑器与水印工坊共用）。
enum PhotoEditTool { rotate, flip, perspective, distort, free, crop }

extension PhotoEditToolInfo on PhotoEditTool {
  String get label => switch (this) {
        PhotoEditTool.rotate => L10n.current.editorToolRotate,
        PhotoEditTool.flip => L10n.current.editorToolFlip,
        PhotoEditTool.perspective => L10n.current.editorToolPerspective,
        PhotoEditTool.distort => L10n.current.editorToolDistortion,
        PhotoEditTool.free => L10n.current.editorToolFreeTransform,
        PhotoEditTool.crop => L10n.current.editorToolCrop,
      };

  String trLabel(BuildContext context) => switch (this) {
        PhotoEditTool.rotate => context.l10n.editorToolRotate,
        PhotoEditTool.flip => context.l10n.editorToolFlip,
        PhotoEditTool.perspective => context.l10n.editorToolPerspective,
        PhotoEditTool.distort => context.l10n.editorToolDistortion,
        PhotoEditTool.free => context.l10n.editorToolFreeTransform,
        PhotoEditTool.crop => context.l10n.editorToolCrop,
      };

  IconData get icon => switch (this) {
        PhotoEditTool.rotate => Icons.rotate_right,
        PhotoEditTool.flip => Icons.flip,
        PhotoEditTool.perspective => Icons.picture_in_picture_alt,
        PhotoEditTool.distort => Icons.grid_on,
        PhotoEditTool.free => Icons.open_with,
        PhotoEditTool.crop => Icons.crop,
      };
}

/// 图片编辑工具条 + 参数面板。
///
/// 只负责“参数编辑”，不负责预览与保存，因此编辑器与工坊可共用同一套 UI。
class PhotoEditToolsPanel extends StatelessWidget {
  final PhotoEditController controller;
  final PhotoEditTool activeTool;
  final ValueChanged<PhotoEditTool> onToolChanged;
  final double cropAspect;
  final ValueChanged<double> onCropAspectSelected;

  /// 宽屏侧栏模式：填满侧栏高度，工具栏改为 3 列 x 2 行网格。
  /// false（默认）时行为与窄屏底部面板完全一致。
  final bool docked;

  const PhotoEditToolsPanel({
    super.key,
    required this.controller,
    required this.activeTool,
    required this.onToolChanged,
    required this.cropAspect,
    required this.onCropAspectSelected,
    this.docked = false,
  });

  void _commit(PhotoEditTransform next) => controller.update(next);

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (docked) return _buildDocked(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            final preferred =
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? 156.0
                    : 220.0;
            final height = math.min(preferred, constraints.maxHeight);
            return SizedBox(
              height: height,
              child: Column(
                children: [
                  SizedBox(height: 56, child: _toolBar(context)),
                  Expanded(
                    child: ColoredBox(
                      color: zc.surface,
                      child: SingleChildScrollView(
                        key: ValueKey(activeTool),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: _panel(context, controller.value),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 宽屏侧栏：工具网格 3x2 + 参数区滚动，整体填满侧栏高度。
  Widget _buildDocked(BuildContext context) {
    final zc = context.zc;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            SizedBox(height: 112, child: _toolGrid(context)),
            Expanded(
              child: ColoredBox(
                color: zc.surface,
                child: SingleChildScrollView(
                  key: ValueKey(activeTool),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: _panel(context, controller.value),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _panel(BuildContext context, PhotoEditTransform t) =>
      switch (activeTool) {
        PhotoEditTool.rotate => _rotatePanel(context, t),
        PhotoEditTool.flip => const SizedBox.shrink(),
        PhotoEditTool.perspective => _perspectivePanel(context, t),
        PhotoEditTool.distort => const SizedBox.shrink(),
        PhotoEditTool.free => _freePanel(context, t),
        PhotoEditTool.crop => _cropPanel(context),
      };

  Widget _title(BuildContext context, String text) {
    final zc = context.zc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: zc.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) =>
      Slider(
        min: min,
        max: max,
        divisions: divisions,
        value: value.clamp(min, max),
        activeColor: context.zc.accent,
        onChangeStart: (_) => controller.beginGesture(),
        onChangeEnd: (_) => controller.endGesture(),
        onChanged: onChanged,
      );

  Widget _rotatePanel(BuildContext context, PhotoEditTransform t) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          context,
          '${l10n.editorToolRotate} ${t.rotationDegrees.toStringAsFixed(0)}°',
        ),
        _slider(
          context,
          t.rotationDegrees,
          -180,
          180,
          72,
          (v) => _commit(t.copyWith(rotationDegrees: v)),
        ),
      ],
    );
  }

  Widget _perspectivePanel(BuildContext context, PhotoEditTransform t) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          context,
          l10n.editorPerspectiveHorizontal(
            (t.perspectiveHorizontal * 100).round(),
          ),
        ),
        _slider(
          context,
          t.perspectiveHorizontal,
          -1,
          1,
          40,
          (v) => _commit(t.copyWith(perspectiveHorizontal: v)),
        ),
        _title(
          context,
          l10n.editorPerspectiveVertical(
            (t.perspectiveVertical * 100).round(),
          ),
        ),
        _slider(
          context,
          t.perspectiveVertical,
          -1,
          1,
          40,
          (v) => _commit(t.copyWith(perspectiveVertical: v)),
        ),
      ],
    );
  }

  Widget _freePanel(BuildContext context, PhotoEditTransform t) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          context,
          '${l10n.editorTransformScale} ${(t.scale * 100).toStringAsFixed(0)}%',
        ),
        _slider(
          context,
          t.scale,
          0.5,
          2.0,
          60,
          (v) => _commit(t.copyWith(scale: v)),
        ),
        _title(
          context,
          '${l10n.editorTransformPanX} ${(t.offsetX * 100).toStringAsFixed(0)}%',
        ),
        _slider(
          context,
          t.offsetX,
          -0.5,
          0.5,
          40,
          (v) => _commit(t.copyWith(offsetX: v)),
        ),
        _title(
          context,
          '${l10n.editorTransformPanY} ${(t.offsetY * 100).toStringAsFixed(0)}%',
        ),
        _slider(
          context,
          t.offsetY,
          -0.5,
          0.5,
          40,
          (v) => _commit(t.copyWith(offsetY: v)),
        ),
      ],
    );
  }

  Widget _cropPanel(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    const landscape = ['原图', '1:1', '4:3', '3:2', '16:9'];
    const portrait = ['3:4', '2:3', '9:16', '自定义'];
    final activeKey = activeCropAspectKey(cropAspect, controller.value.crop);

    String displayLabel(String key) {
      if (key == '原图') return l10n.commonOriginal;
      if (key == '自定义') return l10n.commonCustom;
      return key;
    }

    Widget chip(String name) {
      final active = name == activeKey;
      return InkWell(
        key: ValueKey('crop-ratio-$name'),
        borderRadius: BorderRadius.circular(ZRadius.sm),
        onTap: () => onCropAspectSelected(cropAspectPresets[name]!),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? zc.accent : zc.surfaceHigh,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(color: active ? zc.accent : zc.outline),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayLabel(name),
              style: TextStyle(
                color: active ? zc.onAccent : zc.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    Widget row(List<String> names) => Row(
          children: names
              .map(
                (n) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: chip(n),
                  ),
                ),
              )
              .toList(),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, l10n.editorCropAspectRatio),
        row(landscape),
        const SizedBox(height: 6),
        row(portrait),
      ],
    );
  }

  /// 单条工具按钮（窄屏横排与宽屏网格共用）。
  Widget _toolButton(BuildContext context, PhotoEditTool tool) {
    final zc = context.zc;
    final active = tool == activeTool;
    final text = tool.trLabel(context);
    return Tooltip(
      message: text,
      child: InkWell(
        key: ValueKey('edit-tool-${tool.name}'),
        onTap: () => onToolChanged(tool),
        child: ColoredBox(
          color: active ? zc.surfaceHigh : ZSwatch.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tool.icon,
                size: 20,
                color: active ? zc.accent : zc.textSecondary,
              ),
              const SizedBox(height: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: active ? zc.accent : zc.textSecondary,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBar(BuildContext context) {
    final zc = context.zc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(bottom: BorderSide(color: zc.outline)),
      ),
      child: Row(
        children: PhotoEditTool.values
            .map((tool) => Expanded(child: _toolButton(context, tool)))
            .toList(),
      ),
    );
  }

  /// 宽屏侧栏工具网格：3 列 x 2 行，复用同一套按钮与 key。
  Widget _toolGrid(BuildContext context) {
    final zc = context.zc;
    final tools = PhotoEditTool.values;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(bottom: BorderSide(color: zc.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var r = 0; r < 2; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 3; c++)
                      Expanded(child: _toolButton(context, tools[r * 3 + c])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 裁切比例预设：0 = 原图全幅；-1 = 自定义（解锁比例、保留当前窗口）。
const cropAspectPresets = <String, double>{
  '原图': 0,
  '1:1': 1.0,
  '4:3': 4 / 3,
  '3:2': 3 / 2,
  '16:9': 16 / 9,
  '3:4': 3 / 4,
  '2:3': 2 / 3,
  '9:16': 9 / 16,
  '自定义': -1,
};

/// 当前变换对应的高亮按钮：锁定比例显示预设，手动改过窗口显示自定义。
String activeCropAspectKey(double cropAspect, CropRect crop) {
  if (cropAspect > 0) {
    for (final e in cropAspectPresets.entries) {
      if (e.value == cropAspect) return e.key;
    }
    return '自定义';
  }
  return crop.isFull ? '原图' : '自定义';
}

/// 应用比例按钮：>0 按全图几何重算裁切框；0 恢复原图；-1 解锁比例。
void applyCropAspect(PhotoEditController controller, double aspect) {
  final t = controller.value;
  if (aspect == -1) {
    if (t.cropAspect != 0) controller.update(t.copyWith(cropAspect: 0));
    return;
  }
  if (aspect <= 0) {
    controller.update(t.copyWith(crop: const CropRect(), cropAspect: 0));
    return;
  }
  final w = controller.sourceWidth, h = controller.sourceHeight;
  if (w <= 0 || h <= 0) return;
  controller.update(
    t.copyWith(crop: cropRectForAspect(aspect, w, h), cropAspect: aspect),
  );
}

/// 根据图片尺寸把裁切比例换算成归一化裁切框。
CropRect cropRectForAspect(double aspect, int width, int height) {
  if (aspect <= 0 || width <= 0 || height <= 0) return const CropRect();
  final imageAspect = width / height;
  double w = 1.0, h = 1.0;
  if (imageAspect > aspect) {
    w = aspect / imageAspect;
  } else {
    h = imageAspect / aspect;
  }
  final l = (1 - w) / 2;
  final tp = (1 - h) / 2;
  return CropRect(left: l, top: tp, right: l + w, bottom: tp + h);
}
