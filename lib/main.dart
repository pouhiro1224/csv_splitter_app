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
      executing=true;
    });
    if (file == null) {
      print('ファイルが選択されていません。');
      setState(() {
        executing=false;
      });
      return;
    }

    int linesPerFile = rowsPerFile;
    final inputFile = file;
    if (!inputFile.existsSync()) {
      print('指定したファイルが存在しません。');
      return;
    }

    int fileCount = 0;
    int linesWritten = 0;
    int allLines = 0;
    int allFileCount = 0;

    late File outputFile;
    late IOSink outputSink;

    var inputLines = inputFile.openRead();
    await for (var line in inputLines.transform(Utf8Decoder()).transform(LineSplitter())) {
      allLines++;//ファイルの行数をカウント
    }
    allFileCount = (allLines / linesPerFile).ceil();

    fileCount++;
    String outputFilePath = _directoryPath! + '/output_$fileCount.csv';
    outputFile = File(outputFilePath);
    outputSink = outputFile.openWrite();
    String headerRow = "";

    inputLines = inputFile.openRead();
    await for (var line in inputLines.transform(Utf8Decoder()).transform(LineSplitter())) {
      if(headerRow == ""){
        //最初、ヘッダ行を取っておいて、書き込んでおく
        headerRow = line;
        outputSink.writeln(headerRow);
        continue;
      }
      if (linesWritten != 0 && linesWritten % linesPerFile == 0) {
        if (outputSink != null) {
          await outputSink.close(); // ファイルを閉じるまで待機
          setState(() {
            _value = fileCount/ allFileCount;
          });
        }
        fileCount++;
        outputFilePath = _directoryPath! + '/output_$fileCount.csv';
        outputFile = File(outputFilePath);
        outputSink = outputFile.openWrite();
        //2ファイル目以降は、ヘッダ行を最初に書き込む
        outputSink.writeln(headerRow);
      }

      outputSink.writeln(line);
      linesWritten++;
    }

    if (outputSink != null) {
      await outputSink.close(); // 最後のファイルを閉じるまで待機
    }

    setState(() {
      _value = 1;
      executing=false;
    });
    print('ファイルの分割が完了しました。');
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
          ),
        ),
      ),
    );
  }
}
