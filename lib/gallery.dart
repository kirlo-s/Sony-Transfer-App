import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:sony_camera_api/camera.dart";
import "package:sony_camera_api/core.dart";
import 'package:transferapp/main.dart';

final contentProvider = FutureProvider<List<StillData>>((ref) async{
     print("start");
     final imageList = <StillData>[]; 
     const cnt = 10;
     final Camera camera = ref.read(cameraProvider);
     await camera.action.setCameraFunction(CameraFunction.remoteShooting); //delete later
     await camera.action.startRecMode();
     await camera.action.setCameraFunction(CameraFunction.contentsTransfer);
     final root = (await camera.action.getSource()).source;
     print(root);
     final folderList = <String>[];
     final folderCount = (await camera.action.getContentCount(root, ContentType.nonSpecified, ContentView.date, false)).contentCount;
     print(folderCount);
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
       print(folder);
       int itemCount = (await camera.action.getContentCount(folder, ContentType.still, ContentView.date, false)).contentCount;
       for(int i = 0;i<itemCount;i+=cnt){
         var d = await camera.action.getContentList(folder, i, cnt, ContentType.still, ContentView.date, ContentSort.descending);
         for(dynamic item in d.list){
           if(item.type == DataType.still){
             item as StillData;
             imageList.add(item);
           }
         }
       }
     }
     return imageList;
});

class Gallery extends ConsumerStatefulWidget{
  const Gallery({super.key});

  @override
  GalleryState createState() => GalleryState();
}

class GalleryState extends ConsumerState<Gallery>{
  final imageList = <StillData>[];

  @override
  Widget build(BuildContext context){
    final contentP = ref.watch(contentProvider);
    return Scaffold(
      body:contentP.when(
      data: (data){
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160),
          itemCount: 10,
          itemBuilder: (context,index){
            final item = data[index];
            return GridTile(child: FastCachedImage(url: item.thumbnailUrl)); 
        });
      },
      error: (err, _) => const Text("error"), 
      loading: () => const Center(child: CircularProgressIndicator()))
    );
  }
}


