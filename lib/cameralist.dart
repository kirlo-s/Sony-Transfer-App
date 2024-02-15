import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:permission_handler/permission_handler.dart";

final osInfoProvider = FutureProvider<OperatingSystemInfo?>((ref) async{
  final OperatingSystemInfo osInfo = await _getOSInfo();
  return osInfo;
});

final isPermissionGrantedProvider = StateProvider<bool>((ref) => false);

class CameraList extends ConsumerWidget {
  @override
  Widget build(BuildContext context,WidgetRef ref){
    final osInfo = ref.watch(osInfoProvider);
    if(ref.watch(isPermissionGrantedProvider)){
      return Text("Granted");
    }else{
    return osInfo.when(
      data: (data) {
        if(data!.readPhotosStatus.isGranted || data.storageStatus.isGranted){
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            ref.read(isPermissionGrantedProvider.notifier).state = true;
          });
          return const Text("granted");
        }
        if((data!.os == "android") && (data.sdk > 28)){
          return Column(children: [
                const Text("権限:read_photo"),
                ElevatedButton(onPressed: () async {
                  print("pressed");
                  print(ref.watch(isPermissionGrantedProvider));
                  var readPhotosStatus = await Permission.photos.request();
                  if(readPhotosStatus.isGranted){
                    ref.read(isPermissionGrantedProvider.notifier).state = true;
                  }else{
                    print("permission denied");
                  }
                }, child: Text("取得する"))
              ],);
        }else{
          return Column(children: [
                const Text("権限:storage"),
                ElevatedButton(onPressed: () async {
                  var readStorageStatus = await Permission.storage.request();
                  if(readStorageStatus.isGranted){
                    ref.read(isPermissionGrantedProvider.notifier).state = true;
                  }else{
                    print("permission denied");
                  }
                }, child: Text("取得する"))
              ],);
        }
      }, 
      error: (err, _) => Text("Error"),  
      loading: () => const CircularProgressIndicator());
    }
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
