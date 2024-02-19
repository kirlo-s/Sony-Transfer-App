
import 'package:localstore/localstore.dart';

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