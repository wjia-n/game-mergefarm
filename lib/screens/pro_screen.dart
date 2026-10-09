import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';

/// Merge Farm PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  FarmThemeDef get _t => FarmThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything, farmer!',
              style: Farm.body(15, theme: _t)),
          backgroundColor: _t.woodDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Farm.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      backgroundColor: t.grassLight,
      appBar: AppBar(
        backgroundColor: t.woodDeep,
        foregroundColor: t.surface,
        title: Text('Merge Farm PRO ⭐',
            style: Farm.title(20, theme: t).copyWith(color: t.surface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WoodCard(
            theme: t,
            child: Column(
              children: [
                Text('⭐ Free vs PRO',
                    style: Farm.display(22, theme: t)),
                const SizedBox(height: 10),
                _row(t, 'Farm themes', '4 cozy themes', 'All 12 + creator 🎨'),
                _row(t, 'Crop styles', '4 classic styles',
                    'All 8 + creator ✏️'),
                _row(t, 'Order slots', 'Up to 4', 'Up to 5 📦'),
                _row(t, 'Daily basket', 'Full bonus', 'DOUBLE bonus 📅'),
                _row(t, 'Seasonal events', 'Included 🎪', 'Included 🎪'),
                _row(t, 'Gameplay', 'Full game 🚜', 'Same fair game ✅'),
                const SizedBox(height: 6),
                Text(
                  'PRO is cosmetic + convenience. No pay-to-win — every crop merges the same for everyone.',
                  textAlign: TextAlign.center,
                  style: Farm.muted(12, theme: t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (s.isPro)
            WoodCard(
              theme: t,
              child: Center(
                child: Text('✅ You are PRO — thank you for supporting the farm!',
                    textAlign: TextAlign.center,
                    style: Farm.title(16, theme: t)),
              ),
            )
          else
            _buyBox(t, store),
          const SizedBox(height: 14),
          WoodCard(
            theme: t,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('☕ Tip jar', style: Farm.title(17, theme: t)),
                const SizedBox(height: 6),
                Text(
                  'Love the farm? A coffee keeps the crops growing. Tips are 100% optional.',
                  style: Farm.body(14, theme: t),
                ),
                const SizedBox(height: 10),
                _tipButtons(t, store),
                if (store.error != null && !store.storeReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    store.error == 'Available after store setup'
                        ? '🛠️ Tips unlock after the store products are set up in Play Console.'
                        : '⚠️ ${store.error}',
                    style: Farm.muted(13, theme: t),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () {
                widget.audio.click();
                store.restore();
              },
              child: Text('🔄 Restore purchases',
                  style: Farm.muted(14, theme: t)),
            ),
          ),
          if (store.purchaseError.value != null)
            Center(
              child: Text(store.purchaseError.value!,
                  style: Farm.muted(13, theme: t)),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _row(FarmThemeDef t, String feature, String free, String pro) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(feature,
                  style: Farm.title(14, theme: t))),
          Expanded(
              flex: 3,
              child: Text(free,
                  textAlign: TextAlign.center,
                  style: Farm.muted(13, theme: t))),
          Expanded(
              flex: 4,
              child: Text(pro,
                  textAlign: TextAlign.center,
                  style: Farm.body(13, theme: t)
                      .copyWith(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _buyBox(FarmThemeDef t, StoreService store) {
    final pro = store.proProduct;
    return WoodCard(
      theme: t,
      child: Column(
        children: [
          Text('Unlock PRO forever', style: Farm.title(18, theme: t)),
          const SizedBox(height: 6),
          if (!store.available)
            Text('🛠️ Store unavailable on this device.',
                style: Farm.muted(14, theme: t))
          else if (pro == null)
            Text(
              '🛠️ PRO unlock appears here once the `mergefarmpro` product is created in Play Console.',
              textAlign: TextAlign.center,
              style: Farm.muted(14, theme: t),
            )
          else ...[
            Text(pro.description, style: Farm.muted(13, theme: t)),
            const SizedBox(height: 10),
            FarmButton(
              theme: t,
              label: store.purchaseInProgress.value
                  ? 'Working… ⏳'
                  : 'Unlock PRO — ${pro.price} ⭐',
              fontSize: 17,
              onTap: store.purchaseInProgress.value
                  ? null
                  : () => store.buyPro(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tipButtons(FarmThemeDef t, StoreService store) {
    final tips = <ProductDetails>[
      if (store.coffeeProduct != null) store.coffeeProduct!,
      if (store.chocolateProduct != null) store.chocolateProduct!,
    ];
    if (tips.isEmpty) {
      return Text(
        '☕🍫 Coffee & chocolate tips appear here once `mergefarmcoffee` and `mergefarmchocolate` are created in Play Console.',
        style: Farm.muted(13, theme: t),
      );
    }
    return Row(
      children: [
        for (final p in tips) ...[
          Expanded(
            child: FarmButton(
              theme: t,
              label: p.id == StoreService.coffeeId
                  ? '☕ ${p.price}'
                  : '🍫 ${p.price}',
              fontSize: 15,
              primary: false,
              onTap: store.purchaseInProgress.value
                  ? null
                  : () => store.buyTip(p),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}
