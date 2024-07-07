import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSV分割くん',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'CSV分割くん'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  bool pickSuccess = false; // 読み込みが成功したら true

  late File file;
  late String fileName = "ファイルが選択されていません";
  late String fileContents;
  String? _directoryPath = "出力ディレクトリが選択されていません";
  int rowsPerFile = 0;
  double _value = 0;
  bool executing = false;//実行中か

  Future<void> _pickFileIsSuccess() async {
    final filePickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'], // ピックする拡張子を限定できる。
    );
    String selectFileName = '';
    if (filePickerResult != null) {
      pickSuccess = true;
      file = File(filePickerResult.files.single.path!);
      selectFileName = filePickerResult.files.single.name;
    } else {
      pickSuccess = false;
      selectFileName = '何も選択されませんでした';
      fileContents = 'ファイルの中身がここに表示されます';
    }
    setState(() {
      fileName = selectFileName;
    });
  }

  void _selectFolder() {
    FilePicker.platform.getDirectoryPath().then((value) {
      setState(() => _directoryPath = value);
    });
  }

  Future<void> _splitFile() async {
    setState(() {
      _value = 0;
      executing = true;
    });

    if (file == null) {
      print('ファイルが選択されていません。');
      setState(() {
        executing = false;
      });
      return;
    }

    if (!file!.existsSync()) {
      print('指定したファイルが存在しません。');
      setState(() {
        executing = false;
      });
      return;
    }

    int linesPerFile = rowsPerFile;
    int fileCount = 0;
    int linesWritten = 0;
    int allLines = 0;
    int allFileCount = 0;
    String headerRow = "";
    IOSink? outputSink;

    try {
      // 全行数をカウント
      allLines = await _countLines(file!);
      allFileCount = (allLines / linesPerFile).ceil();

      // 入力ファイルを再度開く
      Stream<String> inputLines = file!.openRead().transform(utf8.decoder).transform(LineSplitter());

      await for (var line in inputLines) {
        if (headerRow.isEmpty) {
          // ヘッダー行を取得
          headerRow = line;
          continue;
        }

        if (linesWritten % linesPerFile == 0) {
          if (linesWritten != 0) {
            await _closeSink(outputSink); // ファイルを閉じる
            setState(() {
              _value = fileCount / allFileCount;
            });
          }
          fileCount++;
          outputSink = await _createNewOutputSink(fileCount, headerRow);
        }

        outputSink!.writeln(line);
        linesWritten++;
      }

      if (outputSink != null) {
        await _closeSink(outputSink); // 最後のファイルを閉じる
      }

      setState(() {
        _value = 1;
        executing = false;
      });
      print('ファイルの分割が完了しました。');
    } catch (e) {
      print('エラーが発生しました: $e');
      setState(() {
        executing = false;
      });
    }
  }

  Future<int> _countLines(File file) async {
    int count = 0;
    await for (var _ in file.openRead().transform(utf8.decoder).transform(LineSplitter())) {
      count++;
    }
    return count;
  }

  Future<IOSink> _createNewOutputSink(int fileCount, String headerRow) async {
    String outputFilePath = '$_directoryPath/output_$fileCount.csv';
    File outputFile = File(outputFilePath);
    IOSink sink = outputFile.openWrite();
    sink.writeln(headerRow);
    return sink;
  }

  Future<void> _closeSink(IOSink? sink) async {
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (executing) ...[
                CircularProgressIndicator(), // ローディングインジケーターを追加
                SizedBox(height: 16),
                LinearProgressIndicator(
                  minHeight: 20,
                  value: _value,
                ),
                SizedBox(height: 8),
                Text(_value == 1 ? "COMPLETE!!" : "処理中..."),
              ] else ...[
                Card(
                  elevation: 4.0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "使い方",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text("分割ファイル、分割後ファイルを出力するディレクトリ、分割する行数を入力したら、分割実行ボタンを押してください。"),
                        Text("出力されるファイルはoutput_{ファイル番号}.csv で出力されます。"),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 4.0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: executing ? null : _pickFileIsSuccess,
                          child: Text("分割ファイル選択"),
                        ),
                        SizedBox(height: 8),
                        Text("分割するファイル：$fileName"),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: executing ? null : _selectFolder,
                          child: Text("出力ディレクトリ選択"),
                        ),
                        SizedBox(height: 8),
                        Text("出力するディレクトリ：${_directoryPath ?? ""}"),
                        SizedBox(height: 16),
                        SizedBox(
                          width: 300,
                          child: TextField(
                            enabled: !executing,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: '分割する行数を入力してください',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (text) {
                              setState(() {
                                if (text.isEmpty) {
                                  rowsPerFile = 0;
                                  return;
                                }
                                rowsPerFile = int.parse(text);
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                        LinearProgressIndicator(
                          minHeight: 20,
                          value: _value,
                        ),
                        SizedBox(height: 8),
                        Text(_value == 1 ? "COMPLETE!!" : ""),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (executing || fileName.isEmpty || _directoryPath == null || rowsPerFile == 0)
                              ? null
                              : _splitFile,
                          child: Text("分割実行"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
