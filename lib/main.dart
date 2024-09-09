import 'dart:async';
import 'dart:io';

import 'package:agmmo/body_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();

  return directory.path;
}

Future<File> get localFile async {
  final path = await _localPath;
  return File('$path/localStorage.txt');
}

bool? isLoggedIn;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(MobileAds.instance.initialize());

  final file = await localFile;

  if (file.existsSync()) {
    final contents = await file.readAsString();
    isLoggedIn = bool.parse(contents);
  } else {
    isLoggedIn = false;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'AntiGraphicsMMO',
      home: MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: BodyWidget(),
      ),
    );
  }
}
