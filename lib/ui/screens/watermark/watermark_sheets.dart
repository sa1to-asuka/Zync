part of '../watermark_screen.dart';

extension _WatermarkScreenSheets on WatermarkScreenState {
  /// 弹出 EXIF 参数手动微调抽屉
  void _showMetadataEditSheet() {
    final cameraController = TextEditingController(text: _metadata.cameraModel);
    final lensController = TextEditingController(text: _metadata.lensModel);
    final apertureController = TextEditingController(text: _metadata.aperture);
    final shutterController =
        TextEditingController(text: _metadata.shutterSpeed);
    final isoController = TextEditingController(text: _metadata.iso);
    final focalController = TextEditingController(text: _metadata.focalLength);
    final dateController = TextEditingController(text: _metadata.capturedDate);
    final latController = TextEditingController(
      text: _metadata.latitude != null
          ? _metadata.latitude!.toStringAsFixed(6)
          : '',
    );
    final lonController = TextEditingController(
      text: _metadata.longitude != null
          ? _metadata.longitude!.toStringAsFixed(6)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.zc.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
      ),
      builder: (ctx) {
        final zc = ctx.zc;
        final l10n = ctx.l10n;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.wmExifSheetTitle,
                      style: TextStyle(
                        color: zc.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: zc.textTertiary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  l10n.wmExifSheetSub,
                  style: TextStyle(color: zc.textTertiary, fontSize: 11),
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  ctx,
                  l10n.wmExifCameraLabel,
                  cameraController,
                  l10n.wmExifCameraHint,
                ),
                const SizedBox(height: 10),
                _buildEditField(
                  ctx,
                  l10n.wmExifLensLabel,
                  lensController,
                  l10n.wmExifLensHint,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditField(
                        ctx,
                        l10n.wmExifApertureLabel,
                        apertureController,
                        l10n.wmExifApertureHint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildEditField(
                        ctx,
                        l10n.wmExifShutterLabel,
                        shutterController,
                        l10n.wmExifShutterHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditField(
                        ctx,
                        l10n.wmExifIsoLabel,
                        isoController,
                        l10n.wmExifIsoHint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildEditField(
                        ctx,
                        l10n.wmExifFocalLabel,
                        focalController,
                        l10n.wmExifFocalHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildEditField(
                  ctx,
                  l10n.wmExifDateLabel,
                  dateController,
                  l10n.wmExifDateHint,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditField(
                        ctx,
                        EngineL10n.gpsLatitudeLabel(l10n.localeName),
                        latController,
                        '31.230416 / 31°13\'49"N',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildEditField(
                        ctx,
                        EngineL10n.gpsLongitudeLabel(l10n.localeName),
                        lonController,
                        '121.473701 / 121°28\'25"E',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final loc = await ExifHelper.fetchPhoneLocation();
                      if (loc != null) {
                        latController.text = loc.latitude.toStringAsFixed(6);
                        lonController.text = loc.longitude.toStringAsFixed(6);
                      } else if (ctx.mounted) {
                        showZToast(
                          ctx,
                          EngineL10n.gpsFetchFailedToast(l10n.localeName),
                          tone: ZStatusTone.warning,
                        );
                      }
                    },
                    icon: Icon(Icons.my_location, size: 14, color: zc.accent),
                    label: Text(
                      EngineL10n.gpsFetchPhoneButton(l10n.localeName),
                      style: TextStyle(
                        color: zc.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: zc.accent,
                      foregroundColor: zc.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZRadius.sm),
                      ),
                    ),
                    onPressed: () {
                      final parsedLat = NikonBleLss.tryParseCoordinate(
                        latController.text,
                        isLatitude: true,
                      );
                      final parsedLon = NikonBleLss.tryParseCoordinate(
                        lonController.text,
                        isLatitude: false,
                      );
                      final clearGps = latController.text.trim().isEmpty &&
                          lonController.text.trim().isEmpty;
                      if (parsedLat != null && parsedLon != null) {
                        NikonBleLss.sessionLatitude = parsedLat;
                        NikonBleLss.sessionLongitude = parsedLon;
                      }
                      _updateState(() {
                        _metadata = _metadata.copyWith(
                          cameraModel: cameraController.text.trim(),
                          lensModel: lensController.text.trim(),
                          aperture: apertureController.text.trim(),
                          shutterSpeed: shutterController.text.trim(),
                          iso: isoController.text.trim(),
                          focalLength: focalController.text.trim(),
                          capturedDate:
                              formatCaptureDate(dateController.text.trim()),
                          latitude: parsedLat,
                          longitude: parsedLon,
                          clearGps: clearGps,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      l10n.wmExifApplyButton,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint,
  ) {
    final zc = context.zc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: zc.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(color: zc.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: zc.textTertiary, fontSize: 12),
            filled: true,
            fillColor: zc.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZRadius.sm),
              borderSide: BorderSide(color: zc.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZRadius.sm),
              borderSide: BorderSide(color: zc.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZRadius.sm),
              borderSide: BorderSide(color: zc.accent),
            ),
          ),
        ),
      ],
    );
  }
}
