
import "package:async/async.dart";

import 'package:dio/dio.dart';

void main() async{
  final dio = Dio();

  final token = CancelToken();
  final original = dio.get(
    "https://placehold.jp/6000x6000.png",
    options: Options(
      responseType: ResponseType.bytes,
    ),
    cancelToken: token,
    onReceiveProgress: (count, total) {
      print(count/total);
    },
  );
  final operation = CancelableOperation.fromFuture(
    original,
    onCancel: token.cancel,
  );

  final calling = Future.sync(() async{
    final res = await operation.valueOrCancellation(null);

  });
  await Future.delayed(Duration(milliseconds: 150));
  operation.cancel();
  await calling;
}