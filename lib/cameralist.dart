import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import "package:localstore/localstore.dart";
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:permission_handler/permission_handler.dart";
import 'package:sony_camera_api/camera.dart';
import 'package:sony_camera_api/core.dart';
import 'package:transferapp/main.dart';
import "util.dart";
import "package:intl/intl.dart";

final osInfoProvider = FutureProvider<OperatingSystemInfo?>((ref) async{
  final OperatingSystemInfo osInfo = await _getOSInfo();
  return osInfo;
});

final isPermissionGrantedProvider = StateProvider<bool>((ref) => false);

enum CameraListMenu {info, edit, delete}

class CameraList extends ConsumerStatefulWidget {
  const CameraList({super.key});

  @override
  CameraListState createState() => CameraListState();
}

class CameraListState extends ConsumerState<CameraList> {
  final _db = Localstore.instance;
  final _items = <String,CameraListEntry>{};
  StreamSubscription<Map<String,dynamic>>? _subscription;

  @override
  void initState(){
    _subscription = _db.collection('cameraList').stream.listen((event) { 
      setState(() {
        final item = CameraListEntry.fromMap(event);
        _items.putIfAbsent(item.id, () => item);
      });
    });
    if(kIsWeb) _db.collection('cameraList').stream.asBroadcastStream();
    super.initState();
  }

  @override
  Widget build(BuildContext context){
    SplayTreeMap.from(_items,(a,b) => _items[a]!.lastConnected.compareTo(_items[b]!.lastConnected));
    final osInfo = ref.watch(osInfoProvider);
    if(ref.watch(isPermissionGrantedProvider)){
      return Scaffold(
        body: Column(
          children: [
            const Text("Title"),
            Flexible(child:  ListView.builder(
              itemCount: _items.keys.length,
              itemBuilder: (context, index) {
                final key = _items.keys.elementAt(index);
                final item = _items[key]!;
                return Card(
                  child: ListTile(
                    title: Text(item.customName),
                    subtitle: Text(item.modelName),
                    onTap: ()async {
                      final customName = item.customName;
                      final modelName = item.modelName;
                      final endpoint = item.endpoint;
                      Camera camera = Camera();
                      camera.initializeDirectly(endpoint, customName, modelName);
                      ref.watch(loadingProvider.notifier).startLoading();
                      var status = (await camera.action.getAvailableApiList()).status;
                      ref.watch(loadingProvider.notifier).stopLoading();
                      if(status == ResponceStatus.success){
                      camera.isInitialized = true;
                      item.lastConnected = DateTime.now();
                      ref.watch(cameraProvider.notifier).state = camera;
                      _items.putIfAbsent(item.id, () => item);
                      }
                    },
                    trailing: PopupMenuButton<CameraListMenu>(
                      onSelected: (CameraListMenu menu) async{
                        if(menu == CameraListMenu.info){
                          _showInfoDialog(context,item);
                        }
                        if(menu == CameraListMenu.edit){
                          String name = await _showEditDialog(context,item);
                          setState(() {
                            item.customName = name.isNotEmpty ? name:item.customName;
                            item.save();
                          });
                        }
                        if(menu == CameraListMenu.delete){
                          bool isDelete = await _showDeleteDialog(context, item);
                          if(isDelete){
                            setState(() {
                              _items.remove(key);
                              item.delete();
                            });
                          }
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<CameraListMenu>>[
                        const PopupMenuItem(
                          value: CameraListMenu.info,
                          child: ListTile(
                            leading: Icon(Icons.info),
                            title: Text("詳細"),
                        )),
                        const PopupMenuItem(
                          value: CameraListMenu.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text("名前の編集"),
                        )),
                        const PopupMenuItem(
                          value: CameraListMenu.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete),
                            title: Text("削除"),
                        ))
                      ],
                    ),
                  ),
                );
              }),)
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: () async{
            ref.read(loadingProvider.notifier).startLoading();
            Camera camera = Camera();
            CameraDataPayload data = await camera.searchCamera(60);
            ref.read(loadingProvider.notifier).stopLoading();
            if(data.get){
              String customName = await _showNewCameraNameDialog(context,data.name);
              camera.isInitialized = true;
              camera.customName = customName;
              camera.modelName = data.name;
              ref.watch(cameraProvider.notifier).state = camera;
              final id = Localstore.instance.collection('cameraList').doc().id;
              final modelName = camera.modelName;
              final endpoint = camera.endpoint;
              final lastConnected = DateTime.now();
              final item = CameraListEntry(id: id, customName: customName, modelName: modelName, endpoint: endpoint,lastConnected: lastConnected);
              item.save();
              _items.putIfAbsent(item.id, () => item);
              print("success");
            }else{
              _showCameraNotFoundDialog(context);
              print("failed");
            }

          },
          tooltip: 'add',
          child: const Icon(Icons.add),
          ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      );
    }else{
    return osInfo.when(
      data: (data) {
        if(data!.readPhotosStatus.isGranted || data.storageStatus.isGranted){
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            ref.read(isPermissionGrantedProvider.notifier).state = true;
          });
          return const Text("granted");
        }
        if((data.os == "android") && (data.sdk > 28)){
          return Column(children: [
                const Text("権限:read_photo"),
                ElevatedButton(onPressed: () async {
                  print("pressed");
                  print(ref.watch(isPermissionGrantedProvider));
                  var readPhotosStatus = await Permission.photos.request();
                  if(readPhotosStatus.isGranted){
                    ref.watch(isPermissionGrantedProvider.notifier).state = true;
                  }else{
                    print("permission denied");
                  }
                }, child: const Text("取得する"))
              ],);
        }else{
          return Column(children: [
                const Text("権限:storage"),
                ElevatedButton(onPressed: () async {
                  var readStorageStatus = await Permission.storage.request();
                  if(readStorageStatus.isGranted){
                    ref.watch(isPermissionGrantedProvider.notifier).state = true;
                  }else{
                    print("permission denied");
                  }
                }, child: const Text("取得する"))
              ],);
        }
      }, 
      error: (err, _) => const Text("Error"),  
      loading: () => const CircularProgressIndicator());
    }
  }

  @override
  void dispose(){
    if (_subscription != null) _subscription?.cancel();
    super.dispose();
  }
}



Future<OperatingSystemInfo> _getOSInfo() async {
  OperatingSystemInfo info = OperatingSystemInfo();
  final deviceInfoPlugin = DeviceInfoPlugin();
  if(Platform.isAndroid){
    info.os = "android";
    final androidInfo = await deviceInfoPlugin.androidInfo;
    info.sdk = androidInfo.version.sdkInt;
  }else if(Platform.isWindows){
    info.os = "windows";
  }
  info.readPhotosStatus = await Permission.photos.status;
  info.storageStatus = await Permission.photos.status;
  return info;
}

class OperatingSystemInfo {
    String os = "";
    int sdk = 0;
    late PermissionStatus readPhotosStatus;
    late PermissionStatus storageStatus;
}

void _showInfoDialog(BuildContext context,CameraListEntry item) {
  showDialog(context: context, builder: (context){
    String name = item.customName;
    String model = item.modelName;
    String endpoint = item.endpoint;
    DateTime lastConnected = item.lastConnected;
    return AlertDialog(
      title: Text(name),
      content:SizedBox(
        width: 0,
        child:ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: const Text("モデル"),
              subtitle: Text(model),
            ),
            ListTile(
              title: const Text("エンドポイント"),
              subtitle: Text(endpoint),
            ),
            ListTile(
              title: const Text("最終接続"),
              subtitle:  Text(DateFormat('yyyy年M月d日 hh:mm:ss').format(lastConnected)),
            )
          ],
        ),
      ),
    );

  });
}

Future<String> _showEditDialog(BuildContext context,CameraListEntry item) async{
  final TextEditingController _controller = TextEditingController();
  String? name_t;
  name_t = await showDialog(context: context, 
    builder: (context) {
      return AlertDialog(
        title: Text('${item.customName}の名前を変更'),
        content: TextField(
          decoration: const InputDecoration(hintText: "入力"),
          controller: _controller,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: (){
              Navigator.pop(context,"");
            }, 
            child: const Text("キャンセル")),
          TextButton(
            onPressed: (){
              Navigator.pop(context,_controller.text);
            }, 
            child: const Text("変更")),
        ],
      );
    });
  return name_t ?? "";
}

Future<bool> _showDeleteDialog(BuildContext context,CameraListEntry item) async{
  bool? isDelete = false;
  isDelete = await showDialog(
    context: context, 
    builder: (context){
      return AlertDialog(
        title: Text("${item.customName}を削除しますか?"),
        actions: <Widget>[
          TextButton(
            onPressed: (){
              Navigator.pop(context,false);
            }, 
            child: const Text("キャンセル")),
          TextButton(
            onPressed: (){
              Navigator.pop(context,true);
            }, 
            child: const Text("削除")),
        ],
      );
    });
  return isDelete ?? false;
}

Future<String> _showNewCameraNameDialog(BuildContext context,String model) async{
final TextEditingController _controller = TextEditingController();
  String? name_t;
  name_t = await showDialog(context: context, 
    builder: (context) {
      return AlertDialog(
        title: const Text('カメラを発見しました'),
        content: SingleChildScrollView(
          child: Column(children: [
          ListTile(
           title: const Text("モデル"), 
           subtitle: Text(model),
          ),
          TextField(
          decoration: const InputDecoration(hintText: "名前を入力してください。"),
          controller: _controller,
        ),
        ]),),
        actions: <Widget>[
          TextButton(
            onPressed: (){
              Navigator.pop(context,_controller.text);
            }, 
            child: const Text("登録")),
        ],
      );
    });
  if(name_t == ""){
    name_t = "defaultName";
  } 
  return name_t ?? "defaultName";
} 

void _showCameraNotFoundDialog(BuildContext context){
  showDialog(
    context: context, 
    builder: (context) {
      return AlertDialog(
        title: const Text("接続に失敗しました"),
        content: const Text("カメラのWifiに接続されていることを確認してください。"),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("OK"))
        ],
    );}
    );
}