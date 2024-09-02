import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BodyWidget extends StatefulWidget {
  const BodyWidget({super.key});

  @override
  BodyWidgetState createState() => BodyWidgetState();
}

class BodyWidgetState extends State<BodyWidget> {
  RewardedInterstitialAd? _rewardedInterstitialAd;

  bool _isMobileAdsInitializeCalled = false;
  WebViewController controller = WebViewController();

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2000110395725890/2400372673'
      : 'ca-app-pub-3940256099942544/4411468910';

  @override
  void initState() {
    super.initState();
    _initializeMobileAdsSDK();
  }

  void _showAdCallback() {
    _rewardedInterstitialAd?.show(
        onUserEarnedReward: (AdWithoutView view, RewardItem rewardItem) {
      _resetAd();
      controller.runJavaScript('window.adWatched()');
    });
  }

  void _resetAd() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
    _loadAd();
  }

  void _loadAd() async {
    RewardedInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {},
              onAdImpression: (ad) {},
              onAdFailedToShowFullScreenContent: (ad, err) {
                _resetAd();
              },
              onAdDismissedFullScreenContent: (ad) {
                _resetAd();
              },
              onAdClicked: (ad) {});

          _rewardedInterstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {},
      ),
    );
  }

  void _initializeMobileAdsSDK() async {
    if (_isMobileAdsInitializeCalled) {
      return;
    }

    _isMobileAdsInitializeCalled = true;
    MobileAds.instance.initialize();
    _loadAd();
  }

  @override
  void dispose() {
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WebViewCookie cookie = const WebViewCookie(
      name: 'from',
      value: 'app',
      domain: 'antigmmo.web.app',
    );
    WebViewCookieManager().setCookie(cookie);

    return WebViewWidget(
      controller: controller
        ..addJavaScriptChannel('Ad',
            onMessageReceived: (JavaScriptMessage message) {
          _loadAd();
          _showAdCallback();
        })
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {},
            onPageStarted: (String url) {},
            onPageFinished: (String url) {},
            onHttpError: (HttpResponseError error) {},
            onWebResourceError: (WebResourceError error) {},
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(
          Uri.parse('https://antigmmo.web.app'),
        ),
    );
  }
}
