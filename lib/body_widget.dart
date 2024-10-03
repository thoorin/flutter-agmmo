import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'main.dart';

String? lastUrl;

class BodyWidget extends StatefulWidget {
  const BodyWidget({super.key});

  @override
  BodyWidgetState createState() => BodyWidgetState();
}

class BodyWidgetState extends State<BodyWidget> {
  RewardedInterstitialAd? _rewardedInterstitialAd;

  bool _isMobileAdsInitializeCalled = false;
  WebViewController controller = WebViewController();
  bool noConnection = false;
  String initialUrl =
      isLoggedIn == true ? '$url/village.html' : '$url/index.html';

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

  changeFile(bool isSignedIn) async {
    final file = await localFile;
    return file.writeAsString(isSignedIn.toString());
  }

  loadPage() {
    return noConnection
        ? controller.loadFlutterAsset('some.html')
        : controller.loadRequest(
            Uri.parse(lastUrl ?? initialUrl),
          );
  }

  recheckConnection() {
    Future.delayed(const Duration(seconds: 1), () {
      http.get(Uri.parse(lastUrl ?? initialUrl)).then((response) {
        if (response.statusCode == 200) {
          setState(() {
            noConnection = false;
          });
        } else {
          recheckConnection();
        }
      }).catchError((error) {
        recheckConnection();
      });
    });
  }

  onNoConnection() {
    controller.loadFlutterAsset('assets/some.html');

    recheckConnection();
  }

  @override
  Widget build(BuildContext context) {
    WebViewCookie cookie = const WebViewCookie(
      name: 'from',
      value: 'app',
      domain: url,
    );
    WebViewCookieManager.fromPlatformCreationParams(
      const PlatformWebViewCookieManagerCreationParams(),
    ).platform.setCookie(cookie);

    noConnection
        ? onNoConnection()
        : controller.loadRequest(
            Uri.parse(lastUrl ?? initialUrl),
          );

    return WebViewWidget(
      controller: controller
        ..addJavaScriptChannel('Ad',
            onMessageReceived: (JavaScriptMessage message) {
          _loadAd();
          _showAdCallback();
        })
        ..addJavaScriptChannel('AuthChannel', onMessageReceived: (message) {
          if (message.message == 'signIn') {
            changeFile(true);
          } else if (message.message == 'signOut') {
            changeFile(false);
          }
        })
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {},
            onPageStarted: (String url) {
              if (!url.endsWith('some.html')) {
                lastUrl = url;
              }
            },
            onPageFinished: (String url) {},
            onHttpError: (HttpResponseError error) {},
            onWebResourceError: (WebResourceError error) {
              // No Connection errorCode
              if (error.errorCode == -2) {
                setState(() {
                  noConnection = true;
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        ),
    );
  }
}
