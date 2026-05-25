import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  InAppWebViewController? webViewController;

  final String fixedUrl = 'http://192.168.1.100:8080';

  bool firstLoadFinished = false;
  bool isOffline = false;

  StreamSubscription? connectivitySubscription;
  Timer? healthCheckTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    startConnectivityListener();
    startHealthCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    connectivitySubscription?.cancel();
    healthCheckTimer?.cancel();

    super.dispose();
  }

  // REMOVE AUTO RELOAD ON RESUME
  // Split screen issue solved

  void startConnectivityListener() {
    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      final connected = result != ConnectivityResult.none;

      if (!connected) {
        if (mounted) {
          setState(() {
            isOffline = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isOffline = false;
          });
        }
      }
    });
  }

  // SMART HEALTH CHECK
  void startHealthCheck() {
    healthCheckTimer =
        Timer.periodic(const Duration(seconds: 20), (timer) async {
      try {
        await webViewController?.evaluateJavascript(
          source: "document.title",
        );
      } catch (_) {
        webViewController?.reload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,

      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(fixedUrl),
            ),

            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,

              // IMPORTANT FIXES
              useHybridComposition: true,
              supportZoom: false,
              transparentBackground: false,
              disableContextMenu: false,

              // KEYBOARD FIX
              isTextInteractionEnabled: true,

              // KEEP WEBVIEW ALIVE
              useShouldOverrideUrlLoading: false,

              // DESKTOP MODE
              preferredContentMode:
                  UserPreferredContentMode.DESKTOP,

              // PERFORMANCE
              verticalScrollBarEnabled: false,
              horizontalScrollBarEnabled: false,

              // iPad typing fix
              allowsBackForwardNavigationGestures: false,
            ),

            onWebViewCreated: (controller) async {
              webViewController = controller;
            },

            onLoadStop: (controller, url) async {
              if (!firstLoadFinished) {
                setState(() {
                  firstLoadFinished = true;
                });
              }

              // Better keyboard + focus fix
              await controller.evaluateJavascript(
                source: """
                  window.focus();

                  document.body.style.overscrollBehavior = 'none';

                  document.addEventListener('touchstart', function(){}, true);

                  const meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content =
                  'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

                  document.getElementsByTagName('head')[0].appendChild(meta);
                """,
              );
            },

            // SMART ERROR HANDLING
            onReceivedError:
                (controller, request, error) async {

              // reload only if main page failed
              if (request.isForMainFrame ?? false) {
                Future.delayed(const Duration(seconds: 5), () {
                  webViewController?.reload();
                });
              }
            },

            onReceivedHttpError:
                (controller, request, response) async {
              if (response.statusCode != null && response.statusCode! >= 500) {
                Future.delayed(const Duration(seconds: 5), () {
                  webViewController?.reload();
                });
              }
            },
          ),

          // ONLY FIRST TIME LOADER
          if (!firstLoadFinished)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "Connecting to Server...",
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

          // OFFLINE BANNER
          if (isOffline)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      "No Internet Connection",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
