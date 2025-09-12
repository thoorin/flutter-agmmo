import 'dart:async';
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
  String initialUrl = isLoggedIn == true ? '$url/village.html' : '$url/index.html';
  bool areChannelsSet = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2000110395725890/2400372673'
      : 'ca-app-pub-2000110395725890/9093983582';

  @override
  void initState() {
    super.initState();
    _initializeMobileAdsSDK();
  }

  void _showAdCallback() {
    _rewardedInterstitialAd?.show(onUserEarnedReward: (AdWithoutView view, RewardItem rewardItem) {
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
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedInterstitialAd failed to load: ${error}');
        },
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

  Future<File> changeFile(bool isSignedIn) async {
    final file = await localFile;
    return file.writeAsString(isSignedIn.toString());
  }

  Future<void> loadPage() {
    return noConnection
        ? controller.loadFlutterAsset('some.html')
        : controller.loadRequest(
            Uri.parse(lastUrl ?? initialUrl),
          );
  }

  void recheckConnection() {
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

  void onNoConnection() {
    controller.loadFlutterAsset('assets/some.html');

    recheckConnection();
  }

  void setChannels() async {
    bool cookieIsSet = false;

    controller
      ..addJavaScriptChannel('Ad', onMessageReceived: (JavaScriptMessage message) {
        print('Ad request from webview');
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
      ..addJavaScriptChannel('OnLoadedChannel', onMessageReceived: (message) {
        if (!cookieIsSet) {
          cookieIsSet = true;
          controller.runJavaScript('window.mobileCookies()');
        }
      });

    areChannelsSet = true;
  }

  @override
  Widget build(BuildContext context) {
    String initialUrl = isLoggedIn == true ? '$url/village.html' : '$url/index.html';

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

    if (!areChannelsSet) {
      setChannels();
    }

    return WebViewWidget(
      controller: controller
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
              print('WebResourceError: ${error.description}, code: ${error.errorCode}');
              // No Connection errorCode
              const androidNoConnectionCode = -2;
              const iosNoConnectionCode = -1009;
              if (error.errorCode == androidNoConnectionCode ||
                  error.errorCode == iosNoConnectionCode) {
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
