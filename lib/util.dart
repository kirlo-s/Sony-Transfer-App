
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
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

class DownloadStatusNotifier extends Notifier<DownloadStatusData>{
  @override
  DownloadStatusData build(){
    return DownloadStatusData(isDownloading: false, isCancel: false, currentCount: 0, photoCount: 0, downloadProgress: 0, currentFileName: "");
  }
  
  void startDownload(int photoCount,String currentFileName){
    state = state.copyWith(isDownloading: true,photoCount: photoCount,currentFileName: currentFileName);    
  }

  void updatePhoto(int currentCount,String currentFilename){
    state = state.copyWith(downloadProgress: 0,currentCount: currentCount,currentFileName: currentFilename);
  }
  void updateProgress(double progress){
    state = state.copyWith(downloadProgress:progress);
  }

  void finishDownload(){
    state = state.copyWith(isDownloading: false, isCancel: false, currentCount: 0, photoCount: 0, downloadProgress: 0, currentFileName: "");
  }

  void cancelDownload(){
    state = state.copyWith(isCancel: true);
  }
}

class DownloadStatusData{
  final bool isDownloading;
  final bool isCancel;
  final int currentCount;
  final int photoCount;
  final double downloadProgress;
  final String currentFileName;
  DownloadStatusData({
    required this.isDownloading,
    required this.isCancel,
    required this.currentCount,
    required this.photoCount,
    required this.downloadProgress,
    required this.currentFileName 
  });

  DownloadStatusData copyWith({bool? isDownloading,bool? isCancel,int? currentCount,int? photoCount,double? downloadProgress,String? currentFileName}){
    return DownloadStatusData(
      isDownloading: isDownloading ?? this.isDownloading, 
      isCancel: isCancel ?? this.isCancel, 
      currentCount: currentCount?? this.currentCount, 
      photoCount: photoCount ?? this.photoCount, 
      downloadProgress: downloadProgress ?? this.downloadProgress, 
      currentFileName: currentFileName ?? this.currentFileName);
  }
}

class CacheDownloadControlNotifier extends Notifier<CacheDownloadControl>{
  @override 
  CacheDownloadControl build(){
    return CacheDownloadControl(cancelToken: CancelToken(), isLocked: false);
  }

  void lock(){
    CancelToken token = state.cancelToken;
    token.cancel();
    state = state.copyWith(isLocked: true);
  }

  void unlock(){
    CancelToken token = CancelToken();
    state = state.copyWith(cancelToken:token,isLocked: false);
  }
}

class CacheDownloadControl{
  final isLocked;
  final cancelToken;
  
  CacheDownloadControl({
    required this.cancelToken,
    required this.isLocked,
  });

  CacheDownloadControl copyWith({CancelToken? cancelToken, bool? isLocked}){
    return CacheDownloadControl(
      cancelToken: cancelToken ?? this.cancelToken,
      isLocked: isLocked ?? this.isLocked,
      );
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

