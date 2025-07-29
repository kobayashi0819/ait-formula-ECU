import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
class CSVHandler {
  Future<String> saveCSV(Map<String, dynamic> jsonData, String fileName) async {
    try {
      // JSONデータをCSV形式に変換
      List<List<String>> rows = [];
      jsonData.forEach((key, value) {
        rows.add([key, value.toString()]);
      });
      String csvData = const ListToCsvConverter().convert(rows);

      // iPhoneのドキュメントディレクトリを取得
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // CSVファイルを書き込む
      final file = File(filePath);
      await file.writeAsString(csvData);

      print('File saved at $filePath');
      return filePath;
    } catch (e) {
      print('Error saving CSV: $e');
      return '';
    }
  }
}
