import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // Landscape lock optional
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Screen always ON
  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Code Server',
      theme: ThemeData.dark(),
      home: const WebScreen(),
    );
  }
}

class WebScreen extends StatefulWidget {
  const WebScreen({super.key});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen>
    with WidgetsBindingObserver {
  InAppWebViewController? webViewController;

  // YAHAN APNA FIX URL DAALO
  final String fixedUrl = 'http://10.103.60.191:3000';

  bool isLoading = true;
  bool isOffline = false;

  Timer? reloadTimer;
  StreamSubscription? connectivitySubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    startConnectivityListener();
    startAutoReload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reloadTimer?.cancel();
    connectivitySubscription?.cancel();
    super.dispose();
  }

  // App background se aaye to reload
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      webViewController?.reload();
    }
  }

  void startConnectivityListener() {
    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        setState(() {
          isOffline = true;
        });
      } else {
        setState(() {
          isOffline = false;
        });

        webViewController?.reload();
      }
    });
  }

  void startAutoReload() {
    reloadTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        await webViewController?.evaluateJavascript(
          source: 'document.body.innerHTML.length',
        );
      } catch (e) {
        webViewController?.reload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await webViewController?.reload();
              },
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(fixedUrl),
                ),

                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  supportZoom: false,
                  transparentBackground: false,
                  disableContextMenu: false,
                  allowsBackForwardNavigationGestures: false,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  useHybridComposition: true,
                  preferredContentMode:
                      UserPreferredContentMode.DESKTOP,
                ),

                onWebViewCreated: (controller) {
                  webViewController = controller;
                },

                onLoadStart: (controller, url) {
                  setState(() {
                    isLoading = true;
                  });
                },

                onLoadStop: (controller, url) async {
                  setState(() {
                    isLoading = false;
                  });

                  // Better desktop feel
                  await controller.evaluateJavascript(
                    source: '''
                      document.body.style.overscrollBehavior = 'none';

                      const meta = document.createElement('meta');
                      meta.name = 'viewport';
                      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                      document.getElementsByTagName('head')[0].appendChild(meta);
                    ''',
                  );
                },

                onReceivedError: (controller, request, error) async {
                  Future.delayed(const Duration(seconds: 3), () {
                    webViewController?.reload();
                  });
                },

                shouldOverrideUrlLoading:
                    (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),

            // Loading Screen
            if (isLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Connecting to Code Server...',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),

            // Offline Banner
            if (isOffline)
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No Internet / Server Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}