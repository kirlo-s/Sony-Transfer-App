import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fast_cached_network_image/fast_cached_network_image.dart";
import "package:transferapp/cameralist.dart";
import "package:path_provider/path_provider.dart";

void main() async{
  //Camera camera = Camera();
  //await camera.searchCamera(60);
  //await camera.action.startRecMode();
  //await camera.action.setCameraFunction(1);
  WidgetsFlutterBinding.ensureInitialized(); 

  String storageLocation = (await getApplicationCacheDirectory()).path;
  await FastCachedImageConfig.init(subDir: storageLocation, clearCacheAfter: const Duration(days: 7));
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TransferApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'TransferApp'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(child: CameraList());
  }
}