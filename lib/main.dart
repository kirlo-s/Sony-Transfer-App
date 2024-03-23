import "dart:io";

import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fast_cached_network_image/fast_cached_network_image.dart";
import "package:sony_camera_api/camera.dart";
import "package:transferapp/cameralist.dart";
import "package:path_provider/path_provider.dart";
import "package:transferapp/gallery.dart";
import "package:transferapp/util.dart";
import "package:dynamic_color/dynamic_color.dart";

final cameraProvider = StateProvider<Camera>((ref){
  Camera camera = Camera();
  return camera;
});

final loadingProvider = NotifierProvider<LoadingNotifier,LoadingData>(LoadingNotifier.new);

final downloadStatusProvider = NotifierProvider<DownloadStatusNotifier,DownloadStatusData>(DownloadStatusNotifier.new);

void main() async{
  //Camera camera = Camera();
  //await camera.searchCamera(60);
  //await camera.action.startRecMode();
  //await camera.action.setCameraFunction(1);
  WidgetsFlutterBinding.ensureInitialized(); 

  String cacheLocation = (await getApplicationCacheDirectory()).path;
  final dir = Directory(cacheLocation);
  dir.deleteSync(recursive: true);
  await FastCachedImageConfig.init(subDir: cacheLocation, clearCacheAfter: const Duration(days: 7));
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic,ColorScheme? darkDynamic){
        return MaterialApp(
          title: 'TransferApp',
          theme: lightTheme(lightDynamic),
          darkTheme: darkTheme(darkDynamic),
          home: const MyHomePage(title: 'TransferApp'),
        );
      },
      );
  }

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final scheme = lightColorScheme ??
        ColorScheme.fromSeed(seedColor: Colors.blue);
    return ThemeData(
      colorScheme: scheme,
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    final scheme = darkColorScheme ??
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        );
    return ThemeData(
      colorScheme: scheme,
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return Stack(
      children: [
          ref.watch(cameraProvider).isInitialized ? const GalleryView():const CameraList(),
          Visibility(
            visible: ref.watch(loadingProvider).isLoading,
            child: const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          Visibility(
            visible: ref.watch(downloadStatusProvider).isDownloading,
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: AlertDialog(
                  title: const Text("ダウンロード中"),
                  content: SizedBox(
                    width: 0,
                    child:ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        ListTile(
                          title: Text("${ref.watch(downloadStatusProvider).currentCount}/${ref.watch(downloadStatusProvider).photoCount}"),
                        ),
                        LinearProgressIndicator(value:ref.watch(downloadStatusProvider).currentCount/ref.watch(downloadStatusProvider).photoCount),
                        ListTile(
                          title: Text("Downloading:${ref.watch(downloadStatusProvider).currentFileName}"),
                        ),
                        LinearProgressIndicator(value: ref.watch(downloadStatusProvider).downloadProgress)
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        ref.watch(downloadStatusProvider.notifier).cancelDownload();
                      }, 
                      child: const Text("Cancel") 
                      ),
                  ],
                  ),
                ),
              ),)    
      ],
    );

  }
}

