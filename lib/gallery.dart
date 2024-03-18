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
import "package:external_path/external_path.dart";


final contentProvider = FutureProvider<List<GalleryEntry>>((ref) async{
  final cacheLocation = (await getApplicationCacheDirectory()).path;
  print("start:");
  DateTime start = DateTime.now();
  final imageList = <GalleryEntry>[]; 
  const cnt = 10;
  final Camera camera = ref.read(cameraProvider);
  //await camera.action.setCameraFunction(CameraFunction.remoteShooting);
  await camera.action.startRecMode();
  await camera.action.setCameraFunction(CameraFunction.contentsTransfer);
  final root = (await camera.action.getSource()).source;
  final folderList = <String>[];
  final folderCount = (await camera.action.getContentCount(root, ContentType.nonSpecified, ContentView.date, false)).contentCount;
  for(int i = 0;i<folderCount;i+=10){
    var f = await camera.action.getContentList(root, i, cnt, ContentType.nonSpecified, ContentView.date, ContentSort.descending);
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


class GalleryView extends ConsumerStatefulWidget{
  const GalleryView({super.key});

  @override
  GalleryViewState createState() => GalleryViewState();
}

class GalleryViewState extends ConsumerState<GalleryView>{
  List<GalleryEntry> galleryList = <GalleryEntry>[];
  int photoViewIndex = -1;
  
  @override
  Widget build(BuildContext context){
    if(photoViewIndex == -1){
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
                  setState(() {
                    photoViewIndex = index;
                  });
                },
                child: GridTile(      
                  child: FutureBuilder(
                    future: cacheThumbnail(item),
                    builder: (context ,snapshot){
                      if(snapshot.hasData){
                        replaceEntry(index, snapshot.data!);
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
    }else{
      StillData photoData = galleryList[photoViewIndex].data as StillData;
      return Scaffold(
        appBar: AppBar(
          leading: TextButton(
            onPressed: (){
              setState(() {
                photoViewIndex = -1;
              });
            }, 
            child: const Icon(Icons.arrow_back)),
        ),
        body: Center(
          child: FutureBuilder(
            future: cachePhotoViewPhoto(galleryList[photoViewIndex]),
            builder: (context, snapshot) {
              if(snapshot.hasData){
                final imageForUint8 =  File(snapshot.data!).readAsBytesSync();
                return Image.memory(imageForUint8);
              }else{
                return const CircularProgressIndicator();
              }
            },
          )
          ),
        floatingActionButton: FloatingActionButton(onPressed: () async{
          ref.watch(loadingProvider.notifier).startLoading();
          if(Platform.isWindows){
            final dir = (await getDownloadsDirectory())!;
            await savePhoto(dir, galleryList[photoViewIndex]);
          }else if(Platform.isAndroid){
            final path = await ExternalPath.getExternalStoragePublicDirectory(
              ExternalPath.DIRECTORY_PICTURES,
            );
            const albumName = "transferAPP";
            final albumPath = '$path/$albumName';
            final dir = await Directory(albumPath).create(recursive: true);
            await savePhoto(dir, galleryList[photoViewIndex]);
            print(dir);
          }
          ref.watch(loadingProvider.notifier).stopLoading();
          setState(() {
            galleryList[photoViewIndex].download = true;
          });
        },
        child: galleryList[photoViewIndex].download ? const Icon(Icons.download_done):const Icon(Icons.download),
      ));
    }
  }

  void replaceEntry(int index,GalleryEntry entry){
    galleryList[index] = entry;
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
          connectionTimeout: Duration(seconds: 5),
          sendTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5)
        )
      );
      isGet = true;
      await file.create();
      await file.writeAsBytes(res.bodyBytes);
    }catch(e){
      print(e);
      isGet = false;
      await Future.delayed(Duration(milliseconds: 2000 + random.nextInt(3000)));
    }
  }
  entry.cachedThumbnailPath = savePath;
  entry.get = true;
  return entry;
}

Future<String> cachePhotoViewPhoto(GalleryEntry entry) async{
  final d = entry.data as StillData;
  String cacheLocation = (await getApplicationCacheDirectory()).path;
  String extension = d.fileName.split('.').last;
  String savePath = "$cacheLocation/photoViewCache.$extension";
  final file = File(savePath);
  if(await file.exists()){
    await file.delete();
  }
  final url = Uri.parse(d.smallUrl);
  ApiResponse res; 
  bool isGet = false;
  Random random = Random();
  while(isGet != true){
    try{
      res = await Api.get(
        url,
        options: const ConnectionOption(
          connectionTimeout: Duration(seconds: 5),
          sendTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5)
        )
      );
      isGet = true;
      await file.create();
      await file.writeAsBytes(res.bodyBytes);
    }catch(e){
      isGet = false;
      await Future.delayed(Duration(milliseconds: random.nextInt(3000)));
    }
  }
  return savePath;
}

  Future<void> savePhoto(Directory saveDir,GalleryEntry entry) async{
    final data = entry.data as StillData;
    final savePath = "${saveDir.path}/${data.fileName}";
    final url = Uri.parse(data.originalUrl);
    final file = File(savePath);
    ApiResponse res; 
    bool isGet = false;
    Random random = Random();
    while(isGet != true){
      try{
        res = await Api.get(
          url,
          options: const ConnectionOption(
            connectionTimeout: Duration(seconds: 5),
            sendTimeout: Duration(seconds: 5),
          )
        );
        isGet = true;
        await file.create();
        await file.writeAsBytes(res.bodyBytes);
      }catch(e){
        print(e);
        isGet = false;
        await Future.delayed(Duration(milliseconds: random.nextInt(3000)));
      }
    }
  }
}



class GalleryEntry{
  bool get = false;
  bool download = false;
  String cachedThumbnailPath = "";
  BaseData data;
  
  GalleryEntry({required this.data});
}




