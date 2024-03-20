import "dart:io";
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import "package:sony_camera_api/camera.dart";
import "package:sony_camera_api/core.dart";
import 'package:transferapp/main.dart';
import "package:external_path/external_path.dart";
import "package:dio/dio.dart";

final downloadLockProvider = StateProvider<bool>((ref) => false);
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
  List<int> selectedItems = <int>[];
  bool isSelectionMode = false;
  
  @override
  Widget build(BuildContext context){
    print(selectedItems);
    if(photoViewIndex == -1){
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if(isSelectionMode){
          ref.watch(downloadLockProvider.notifier).state = true;
        }else{
          ref.watch(downloadLockProvider.notifier).state = false;
        }
      });
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
                    if(isSelectionMode){
                      if(item.download){
                        return;
                      }
                      if(selectedItems.contains(index)){
                        setState(() {
                          selectedItems.remove(index);
                        });
                      }else{
                        setState(() {
                          selectedItems.add(index);
                        });
                      }
                    }else{
                      setState(() {
                        photoViewIndex = index;
                      });
                    }
                },
                onLongPress: () {
                  if(!isSelectionMode){
                    setState(() {
                      if(!item.download){
                        selectedItems.add(index);
                      }
                      isSelectionMode = !isSelectionMode;
                    });
                  }
                },
                child: Center(
                  child:Stack(children: [
                  GridTile(      
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
                  Visibility(
                    visible: isSelectionMode,
                    child: item.download ?
                    Container(
                        margin: const EdgeInsets.all(10),
                        color: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.download_done)
                    ):
                    Checkbox(
                      onChanged :(bool? x) {
                          if(x!){
                            setState(() {
                              selectedItems.add(index);
                            });
                          }else{
                            setState(() {
                              selectedItems.remove(index);
                            });
                          }
                      },
                      value: selectedItems.contains(index),
                    ))
                ],),)
              );
          });
        },
        error: (err, _) => const Text("error"), 
        loading: () => const Center(child: CircularProgressIndicator())),
        floatingActionButton: Visibility(
          visible: isSelectionMode,
          child: FloatingActionButton(
            onPressed: ()async{
              await savePhoto(selectedItems, galleryList);
              setState(() {
                isSelectionMode = false;
                selectedItems.clear();
              });
            },
            child: const Icon(Icons.download),
            )),
      );
    }else{
      StillData photoData = galleryList[photoViewIndex].data as StillData;
    WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.watch(downloadLockProvider.notifier).state = true;
      });
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
        floatingActionButton: 
        galleryList[photoViewIndex].download ? 
          null:
          FloatingActionButton(
            onPressed: galleryList[photoViewIndex].download ? 
            null:
            () async{
            await savePhoto([photoViewIndex],galleryList);  
            setState(() {
              galleryList[photoViewIndex].download = true;
            });
          },
          child: const Icon(Icons.download),
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
  final url = d.thumbnailUrl;
  Response res; 
  bool isGet = false;
  Random random = Random();
  while(isGet != true){
    if(ref.watch(downloadLockProvider)){
      print("canceled");
    }
    try{
      res = await Dio().get(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 5),
            ),
          );
      isGet = true;
      await file.create();
      await file.writeAsBytes(res.data);
    }catch(e){
      print(e);
      isGet = false;
      await Future.delayed(Duration(milliseconds: 2000 + random.nextInt(3000)));
    }
  }

  if(isGet){
    entry.cachedThumbnailPath = savePath;
    entry.get = true;
  }
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
  final url = d.smallUrl;
  Response res; 
  bool isGet = false;
  Random random = Random();
  while(isGet != true){
    try{
      res = await Dio().get(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 5),
            ),
          );
      isGet = true;
      await file.create();
      await file.writeAsBytes(res.data);
    }catch(e){
      isGet = false;
      await Future.delayed(Duration(milliseconds: random.nextInt(3000)));
    }
  }
  return savePath;
}

  Future<void> savePhoto(List<int> selectedItems,List<GalleryEntry> galleryList) async{
    if(selectedItems.isEmpty) return;
    var d = galleryList[selectedItems.first].data as StillData;
    ref.watch(downloadStatusProvider.notifier).startDownload(selectedItems.length, d.fileName);
    var saveDir;
    if(Platform.isWindows){
      saveDir = (await getDownloadsDirectory())!;
    }else if(Platform.isAndroid){
      final path = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_PICTURES,
      );
      const albumName = "transferAPP";
      final albumPath = '$path/$albumName';
      saveDir = await Directory(albumPath).create(recursive: true);
    }
    int count = 0;
    for(int index in selectedItems){
      count += 1;
      GalleryEntry entry = galleryList[index];
      final data = entry.data as StillData;
      ref.watch(downloadStatusProvider.notifier).updatePhoto(count, data.fileName);
      final savePath = "${saveDir.path}/${data.fileName}";
      final url  = data.originalUrl;
      final file = File(savePath);
      Response res; 
      bool isGet = false;
      Random random = Random();
      while(isGet != true){
        try{
          res = await Dio().get(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 5),
            ),
            onReceiveProgress: (count, total) => ref.watch(downloadStatusProvider.notifier).updateProgress(count/total),
          );
          isGet = true;
          await file.create();
          await file.writeAsBytes(res.data);
        }catch(e){
          print(e);
          isGet = false;
          await Future.delayed(Duration(milliseconds: random.nextInt(3000)));
        }
      }
      print("$savePath saved");
      galleryList[index].download = true;
    }
    ref.watch(downloadStatusProvider.notifier).finishDownload();
  }
  
}



class GalleryEntry{
  bool get = false;
  bool download = false;
  String cachedThumbnailPath = "";
  BaseData data;
  
  GalleryEntry({required this.data});
}

class DownloadInfo{
  
}




