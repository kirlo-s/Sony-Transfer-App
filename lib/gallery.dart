import "dart:io";
import 'dart:math';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import "package:sony_camera_api/camera.dart";
import "package:sony_camera_api/core.dart";
import 'package:transferapp/main.dart';
import "package:simple_http_api/simple_http_api.dart";


final contentProvider = FutureProvider<List<GalleryEntry>>((ref) async{
  final cacheLocation = (await getApplicationCacheDirectory()).path;
  print("start");
  DateTime start = DateTime.now();
  final imageList = <GalleryEntry>[]; 
  const cnt = 10;
  final Camera camera = ref.read(cameraProvider);
  await camera.action.setCameraFunction(CameraFunction.remoteShooting);
  await camera.action.startRecMode();
  await camera.action.setCameraFunction(CameraFunction.contentsTransfer);
  final root = (await camera.action.getSource()).source;
  final folderList = <String>[];
  final folderCount = (await camera.action.getContentCount(root, ContentType.nonSpecified, ContentView.date, false)).contentCount;
  for(int i = 0;i<folderCount;i+=10){
    var f = await camera.action.getContentList(root, i, cnt, ContentType.nonSpecified, ContentView.date, ContentSort.ascending);
    for(dynamic item in f.list){
      if(item.type == DataType.directory){
          item as DirectoryData;
          folderList.add(item.uri);
      }
    }
  }
  for(String folder in folderList){
    int itemCount = (await camera.action.getContentCount(folder, ContentType.still, ContentView.date, false)).contentCount;
    for(int i = 0;i<itemCount;i+=cnt){
      var d = await camera.action.getContentList(folder, i, cnt, ContentType.still, ContentView.date, ContentSort.descending);
      for(dynamic item in d.list){
        if(item.type == DataType.still){
          item as StillData;
            GalleryEntry entry = GalleryEntry(data: item);
            entry.get = false;
            imageList.add(entry);
        }
      }
    }
    print("end");
    DateTime end = DateTime.now();
    print("${(end.millisecondsSinceEpoch-start.millisecondsSinceEpoch)/1000}");

  }
  return imageList;
});


class Gallery extends ConsumerStatefulWidget{
  const Gallery({super.key});

  @override
  GalleryState createState() => GalleryState();
}

class GalleryState extends ConsumerState<Gallery>{
  List<GalleryEntry> galleryList = <GalleryEntry>[];
  @override
  Widget build(BuildContext context){
    final contentP = ref.watch(contentProvider);
    return Scaffold(
      body:contentP.when(
      data: (data){
        galleryList = contentP.value!;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160),
          itemCount: galleryList.length,
          itemBuilder: (context,index) {
            final item = galleryList[index];
            final d = item.data as StillData;
            return InkWell(
              onTap: () async {
                print(galleryList[index].get);
              },
              child: GridTile(      
                child: FutureBuilder(
                  future: cacheThumbnail(item),
                  builder: (context ,snapshot){
                    if(snapshot.hasData){
                      galleryList[index] = snapshot.data!;
                      return Image.file(File(item.cachedThumbnailPath));
                    }else{
                      return const CircularProgressIndicator();
                    }
                })),
            );
        });
      },
      error: (err, _) => const Text("error"), 
      loading: () => const Center(child: CircularProgressIndicator()))
    );
  }
}

class GalleryEntry{
  bool get = false;
  String cachedThumbnailPath = "";
  BaseData data;
  
  GalleryEntry({required this.data});
}


Future<GalleryEntry> cacheThumbnail(GalleryEntry entry) async{
  if(entry.get){
    return entry;
  }
  final d = entry.data as StillData;
  String cacheLocation = (await getApplicationCacheDirectory()).path;
  String savePath = "$cacheLocation/${d.fileName}";
  final file = File(savePath);
  final url = Uri.parse(d.thumbnailUrl);
  ApiResponse res; 
  bool isGet = false;
  Random random = Random();
  while(isGet != true){
    try{
      res = await Api.get(
        url,
        options: const ConnectionOption(
          connectionTimeout: Duration(seconds: 10),
          sendTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10)
        )
      );
      isGet = true;
      await file.create();
      await file.writeAsBytes(res.bodyBytes);
    }catch(e){
      isGet = false;
      await Future.delayed(Duration(seconds: random.nextInt(5)));
    }
  }
  entry.cachedThumbnailPath = savePath;
  entry.get = true;
  return entry;
}

