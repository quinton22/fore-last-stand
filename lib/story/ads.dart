import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'save.dart';

/// Rewarded ads (6a.12). Ads are always optional and there are no
/// interstitials. No ad SDK is wired up yet: [NoAdService] hides the buttons
/// (as when offline or no ad is loaded), and [SimulatedAdService] stands in
/// for testing the flow. A `google_mobile_ads` implementation slots in here.
abstract class AdService {
  const AdService();

  /// True when a rewarded ad is loaded and can be shown.
  bool get ready;

  /// Shows a rewarded ad. Completes true only if it was watched to the end.
  Future<bool> showRewarded(BuildContext context);
}

class NoAdService extends AdService {
  const NoAdService();

  @override
  bool get ready => false;

  @override
  Future<bool> showRewarded(BuildContext context) async => false;
}

/// A 3-second stand-in ad. Closing it early gives no reward.
class SimulatedAdService extends AdService {
  const SimulatedAdService({this.seconds = 3});

  final int seconds;

  @override
  bool get ready => true;

  @override
  Future<bool> showRewarded(BuildContext context) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FakeAd(seconds: seconds),
    );
    return done ?? false;
  }
}

class _FakeAd extends StatefulWidget {
  const _FakeAd({required this.seconds});

  final int seconds;

  @override
  State<_FakeAd> createState() => _FakeAdState();
}

class _FakeAdState extends State<_FakeAd> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        _timer?.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Test ad'),
    content: Text('Stand-in for a rewarded ad. Reward in $_left s.'),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close (no reward)'))],
  );
}

/// Whether a rewarded perk can be offered: Remove Ads owners get it without watching.
bool canOfferReward(PlayerSave p, AdService ads) => p.removeAds || ads.ready;

/// Grants a rewarded perk: free for Remove Ads owners, otherwise only if the ad completes.
Future<bool> earnReward(BuildContext context, PlayerSave p, AdService ads) async {
  if (p.removeAds) return true;
  if (!ads.ready) return false;
  return ads.showRewarded(context);
}
