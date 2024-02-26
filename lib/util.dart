
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:localstore/localstore.dart';
import "package:riverpod/riverpod.dart";
import "package:path_provider/path_provider.dart";
import 'package:sony_camera_api/core.dart';
import "package:http/http.dart" as http;

class CameraListEntry {
  final String id;
  String customName;
  String modelName;
  String endpoint;
  DateTime lastConnected;
  bool placeholder = false;
  
  CameraListEntry({
    required this.id,
    required this.customName,
    required this.modelName,
    required this.endpoint,
    required this.lastConnected,
  });

  Map<String,dynamic> toMap(){
    return{
      'id'        : id,
      'customName': customName,
      'modelName' : modelName,
      'endpoint'  : endpoint,
      'lastConnected' : lastConnected.millisecondsSinceEpoch,
    };
  }

  factory CameraListEntry.fromMap(Map<String,dynamic> map){
    return CameraListEntry(
      id: map['id'], 
      customName: map['customName'], 
      modelName: map['modelName'], 
      endpoint: map['endpoint'],
      lastConnected: DateTime.fromMillisecondsSinceEpoch(map['lastConnected']),
    );
  }
}

extension ExtCameraData on CameraListEntry {
  Future save() async {
    final db = Localstore.instance;
    return db.collection('cameraList').doc(id).set(toMap());
  }

  Future delete() async {
    final db = Localstore.instance;
    return db.collection('cameraList').doc(id).delete();
  }
}

class LoadingData {
  final bool isLoading;
  LoadingData({
    required this.isLoading
  });

  LoadingData copyWith({bool? isLoading}){
    return LoadingData(
     isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LoadingNotifier extends Notifier<LoadingData>{
  @override
  LoadingData build(){
    return LoadingData(isLoading: false);
  }
  void startLoading(){
    state = state.copyWith(isLoading: true);
  }
  void stopLoading(){
    state = state.copyWith(isLoading: false);
  }

}

Future<PhotoCacheData> cacheThumbnailPhoto(StillData entry) async {
  PhotoCacheData photo = PhotoCacheData();
  String cacheLocation = (await getApplicationCacheDirectory()).path;
  String imgPath = "$cacheLocation/${entry.fileName}";
  final http.Response res = await http.get(Uri.parse(entry.thumbnailUrl));
  print(res.statusCode);
  final file = File(imgPath);
  await file.create();
  await file.writeAsBytes(res.bodyBytes);
  return PhotoCacheData();
}

class PhotoCacheData {
  bool get = false;
  String location = "";
}

