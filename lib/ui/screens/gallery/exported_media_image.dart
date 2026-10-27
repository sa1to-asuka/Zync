part of '../gallery_screen.dart';

/// URI 媒体与旧路径共用的图片组件，缓存 Future 防止每次重建重复复制。
class ExportedMediaImage extends StatefulWidget {
  final ExportedMediaItem item;
  final BoxFit fit;
  final int? cacheWidth;
  final ImageErrorWidgetBuilder? errorBuilder;

  const ExportedMediaImage({
    super.key,
    required this.item,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.errorBuilder,
  });

  @override
  State<ExportedMediaImage> createState() => _ExportedMediaImageState();
}

class _ExportedMediaImageState extends State<ExportedMediaImage> {
  late Future<File> _file;
  Future<Uint8List?>? _rawPreview;

  Future<File> _load() async {
    final file = await ExportHistoryManager().ensureLocalFile(widget.item);
    await FileImage(file).evict();
    return file;
  }

  /// RAW（NEF/NRW）无法被 Image.file 解码，改为提取内嵌 JPEG 预览。
  Future<Uint8List?> _loadRawPreview() async {
    try {
      final file = await _file;
      return await RawPreviewExtractor.extractEmbeddedJpeg(
        await file.readAsBytes(),
      );
    } catch (_) {
      return null;
    }
  }

  void _reset() {
    _file = _load();
    _rawPreview = widget.item.isRaw ? _loadRawPreview() : null;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(ExportedMediaImage old) {
    super.didUpdateWidget(old);
    if (old.item.mediaUri != widget.item.mediaUri ||
        old.item.file.path != widget.item.file.path ||
        old.item.modifiedTime != widget.item.modifiedTime) {
      _reset();
    }
  }

  Widget _placeholder(BuildContext context) =>
      widget.errorBuilder?.call(context, 'no preview', null) ??
      Icon(Icons.broken_image_outlined, color: context.zc.textSecondary);

  @override
  Widget build(BuildContext context) {
    if (widget.item.isRaw) {
      return FutureBuilder<Uint8List?>(
        future: _rawPreview,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _placeholder(context);
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return _placeholder(context);
          return Image.memory(
            bytes,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            errorBuilder: widget.errorBuilder,
          );
        },
      );
    }
    return FutureBuilder<File>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _placeholder(context);
        if (snapshot.data == null) {
          return _placeholder(context);
        }
        return Image.file(
          snapshot.data!,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}
