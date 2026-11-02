part of '../watermark_screen.dart';

extension _WatermarkScreenSpektrafilmPanel on WatermarkScreenState {
  Widget _buildSpektrafilmPanel() {
    _ensureSpektraCatalog();
    final zc = context.zc;
    final l = context.l10n;
    final isRaw = _rawSourcePath != null && _rawSourcePath!.isNotEmpty;

    return Container(
      color: zc.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ZSpace.lg,
                ZSpace.md,
                ZSpace.lg,
                ZSpace.md,
              ),
              children: [
                if (!isRaw) _buildRawTip(l),
                if (_isFilmActive) _buildActiveFilmHeader(l),
                _buildFilmSectionTitle(
                  l.spektraStockSection,
                  Icons.local_movies_outlined,
                ),
                const SizedBox(height: ZSpace.xs),
                if (_spektraCatalogUnavailable)
                  _buildCatalogUnavailable(l)
                else if (_spektraStocks.isEmpty)
                  const SizedBox(
                    height: 148,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SizedBox(height: 148, child: _buildStockStrip()),
                const SizedBox(height: ZSpace.md),
                _buildFilmSectionTitle(
                  l.spektraPaperSection,
                  Icons.print_outlined,
                ),
                const SizedBox(height: ZSpace.xs),
                _buildPaperChips(),
                const SizedBox(height: ZSpace.md),
                ..._buildFilmParamSliders(l),
                const SizedBox(height: ZSpace.md),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawTip(AppLocalizations l) {
    final zc = context.zc;
    return Container(
      margin: const EdgeInsets.only(bottom: ZSpace.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: zc.info),
          const SizedBox(width: ZSpace.sm),
          Expanded(
            child: Text(
              l.spektraRawTip,
              style: TextStyle(color: zc.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogUnavailable(AppLocalizations l) {
    final zc = context.zc;
    return Container(
      height: 148,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(ZSpace.md),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outline),
      ),
      child: Text(
        l.spektraCatalogUnavailable,
        textAlign: TextAlign.center,
        style: TextStyle(color: zc.textTertiary, fontSize: 11),
      ),
    );
  }

  Widget _buildActiveFilmHeader(AppLocalizations l) {
    final zc = context.zc;
    final stockMatches =
        _spektraStocks.where((item) => item.id == _spektrafilm.stockId);
    final stockName = stockMatches.isEmpty ? '' : stockMatches.first.name;
    final paperMatches =
        _spektraPapers.where((paper) => paper.id == _spektrafilm.paperId).toList();
    final paperName = _spektrafilm.directScan
        ? l.spektraDirectScan
        : (paperMatches.isEmpty ? null : paperMatches.first.name);
    final processing = _filmPreview?.isProcessing ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: ZSpace.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.accentContainer,
        borderRadius: ZRadius.brSm,
      ),
      child: Row(
        children: [
          if (processing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: zc.accent,
              ),
            )
          else
            Icon(Icons.check_circle, size: 15, color: zc.accent),
          const SizedBox(width: ZSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paperName == null || paperName.isEmpty
                      ? stockName
                      : '$stockName · $paperName',
                  style: TextStyle(
                    color: zc.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.spektraActiveHint,
                  style: TextStyle(color: zc.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _disableSpektrafilm(),
            child: Text(l.spektraDisable),
          ),
        ],
      ),
    );
  }

  Widget _buildFilmSectionTitle(String title, IconData icon) {
    final zc = context.zc;
    return Row(
      children: [
        Icon(icon, size: 15, color: zc.textSecondary),
        const SizedBox(width: ZSpace.sm),
        Text(
          title,
          style: TextStyle(
            color: zc.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStockStrip() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _spektraStocks.length,
      separatorBuilder: (_, __) => const SizedBox(width: ZSpace.sm),
      itemBuilder: (context, index) =>
          _buildStockCard(_spektraStocks[index]),
    );
  }

  ({int body, int label, int ink, int accent}) _stockPalette(String vendor) {
    switch (vendor) {
      case 'Kodak':
        return (
          body: 0xFFD8A21E,
          label: 0xFFF3E7C8,
          ink: 0xFF3B2B12,
          accent: 0xFFB8781A,
        );
      case 'Fujifilm':
        return (
          body: 0xFF2F6B4F,
          label: 0xFFE8F1E6,
          ink: 0xFF13301F,
          accent: 0xFF1F4C36,
        );
      case 'CineStill':
        return (
          body: 0xFF2A1113,
          label: 0xFFE3C9C4,
          ink: 0xFF1A0A0B,
          accent: 0xFFC3161C,
        );
      case 'Ilford':
        return (
          body: 0xFF1B1B1B,
          label: 0xFFF0EEE8,
          ink: 0xFF101010,
          accent: 0xFF7A7A7A,
        );
      default:
        return (
          body: 0xFF3A3F46,
          label: 0xFFE6E8EA,
          ink: 0xFF14171A,
          accent: 0xFF6D747C,
        );
    }
  }

  Widget _buildStockCard(SpektraStockInfo stock) {
    final zc = context.zc;
    final selected = _spektrafilm.stockId == stock.id;
    final palette = _stockPalette(stock.vendor);
    final body = Color(palette.body);
    final label = Color(palette.label);
    final ink = Color(palette.ink);
    final accent = Color(palette.accent);
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: () => _activateFilmStock(stock.id),
        borderRadius: ZRadius.brSm,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            ZSpace.xs,
            ZSpace.xs,
            ZSpace.xs,
            ZSpace.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? zc.accent.withAlpha(30) : zc.surface,
            borderRadius: ZRadius.brSm,
            border: Border.all(
              color: selected ? zc.accent : zc.outline,
              width: selected ? ZStroke.emphasis : ZStroke.hairline,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color.lerp(body, ZSwatch.pureBlack, 0.18)!,
                            body,
                            Color.lerp(body, ZSwatch.pureWhite, 0.12)!,
                          ],
                        ),
                        border: Border.all(
                          color: ZFilmSwatch.canisterEdge,
                          width: ZStroke.hairline,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: ZFilmSwatch.spoolMetal,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: ZFilmSwatch.spoolShadow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 3,
                      ),
                      decoration: BoxDecoration(
                        color: label,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(
                            color: ZFilmSwatch.labelShadow,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(height: 2, color: accent),
                          const SizedBox(height: 3),
                          Text(
                            '${stock.iso}',
                            style: TextStyle(
                              color: ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            stock.vendor.toUpperCase(),
                            style: TextStyle(
                              color: ink.withAlpha(200),
                              fontSize: 6.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.check_circle,
                          size: 15,
                          color: zc.accent,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: ZSpace.xs),
              Text(
                stock.name,
                style: TextStyle(
                  color: selected ? zc.accent : zc.textPrimary,
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  height: 1.15,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperChips() {
    final zc = context.zc;
    final l = context.l10n;
    final papers = <SpektraPaperInfo>[
      const SpektraPaperInfo(
        id: kSpektraDirectScanPaperId,
        name: '',
      ),
      ..._spektraPapers,
    ];
    return Wrap(
      spacing: ZSpace.sm,
      runSpacing: ZSpace.xs,
      children: [
        for (final paper in papers)
          Builder(builder: (context) {
            final selected =
                _isFilmActive && _spektrafilm.paperId == paper.id;
            final isDirect = paper.id == kSpektraDirectScanPaperId;
            return ChoiceChip(
              label: Text(isDirect ? l.spektraDirectScan : paper.name),
              selected: selected,
              onSelected: (value) {
                if (!value) return;
                _setSpektrafilm(
                  _spektrafilm.copyWith(paperId: paper.id),
                );
              },
              selectedColor: zc.accent,
              backgroundColor: zc.surface,
              labelStyle: TextStyle(
                color: selected ? zc.onAccent : zc.textSecondary,
                fontSize: 11,
              ),
              side: BorderSide(
                color: selected ? zc.accent : zc.outline,
                width: ZStroke.hairline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              showCheckmark: false,
            );
          }),
      ],
    );
  }

  List<Widget> _buildFilmParamSliders(AppLocalizations l) {
    final s = _spektrafilm;
    String pct(double v) => '${(v * 100).round()}%';
    String ev(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}EV';
    return [
      ZSlider(
        label: l.spektraIntensity,
        value: s.intensity,
        min: 0,
        max: 1,
        defaultValue: 1,
        divisions: 20,
        valueText: pct(s.intensity),
        icon: Icons.opacity,
        onChanged: (v) => _setSpektrafilm(s.copyWith(intensity: v)),
      ),
      ZSlider(
        label: l.spektraHalation,
        value: s.halation,
        min: 0,
        max: 1,
        defaultValue: 1,
        divisions: 20,
        valueText: pct(s.halation),
        icon: Icons.flare,
        onChanged: (v) => _setSpektrafilm(s.copyWith(halation: v)),
      ),
      ZSlider(
        label: l.spektraHalationRadius,
        value: s.halationRadius,
        min: 0.5,
        max: 3,
        defaultValue: 1,
        divisions: 25,
        valueText: s.halationRadius.toStringAsFixed(1),
        icon: Icons.blur_circular_outlined,
        onChanged: (v) => _setSpektrafilm(s.copyWith(halationRadius: v)),
      ),
      ZSlider(
        label: l.spektraGrain,
        value: s.grain,
        min: 0,
        max: 1,
        defaultValue: 1,
        divisions: 20,
        valueText: pct(s.grain),
        icon: Icons.grain,
        onChanged: (v) => _setSpektrafilm(s.copyWith(grain: v)),
      ),
      ZSlider(
        label: l.spektraGrainSize,
        value: s.grainRoughness,
        min: 0,
        max: 1,
        defaultValue: 0.45,
        divisions: 20,
        valueText: pct(s.grainRoughness),
        icon: Icons.blur_on,
        onChanged: (v) => _setSpektrafilm(s.copyWith(grainRoughness: v)),
      ),
      ZSlider(
        label: l.spektraEnlargerWarmth,
        value: s.enlargerWarmth,
        min: -100,
        max: 100,
        defaultValue: 0,
        divisions: 40,
        valueText: '${s.enlargerWarmth.round()}',
        icon: Icons.wb_incandescent_outlined,
        trackGradient: ZSwatch.wbTemperatureGradient,
        onChanged: (v) => _setSpektrafilm(s.copyWith(enlargerWarmth: v)),
      ),
      ZSlider(
        label: l.spektraEnlargerTint,
        value: s.enlargerTint,
        min: -100,
        max: 100,
        defaultValue: 0,
        divisions: 40,
        valueText: '${s.enlargerTint.round()}',
        icon: Icons.colorize_outlined,
        trackGradient: ZSwatch.wbTintGradient,
        onChanged: (v) => _setSpektrafilm(s.copyWith(enlargerTint: v)),
      ),
      ZSlider(
        label: l.spektraExposure,
        value: s.filmExposure,
        min: -2,
        max: 2,
        defaultValue: 0,
        divisions: 40,
        valueText: ev(s.filmExposure),
        icon: Icons.exposure_outlined,
        onChanged: (v) => _setSpektrafilm(s.copyWith(filmExposure: v)),
      ),
    ];
  }
}
