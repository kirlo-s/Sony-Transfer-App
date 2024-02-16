
import 'package:localstore/localstore.dart';

class CameraData {
  final String id;
  String customName;
  String modelName;
  String endpoint;
  DateTime lastConnected;
  
  CameraData({
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

  factory CameraData.fromMap(Map<String,dynamic> map){
    return CameraData(
      id: map['id'], 
      customName: map['customName'], 
      modelName: map['modelName'], 
      endpoint: map['endpoint'],
      lastConnected: DateTime.fromMillisecondsSinceEpoch(map['lastConnected']),
    );
  }
}

extension ExtCameraData on CameraData {
  Future save() async {
    final db = Localstore.instance;
    return db.collection('cameraList').doc(id).set(toMap());
  }

  Future delete() async {
    final db = Localstore.instance;
    return db.collection('cameraList').doc(id).delete();
  }
}