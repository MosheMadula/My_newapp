import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:async';

void main() => runApp(MarketReplayApp());

class MarketReplayApp extends StatelessWidget {
  const MarketReplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Replay',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ReplayHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ReplayHomePage extends StatefulWidget {
  const ReplayHomePage({super.key});

  @override
  _ReplayHomePageState createState() => _ReplayHomePageState();
}

class _ReplayHomePageState extends State<ReplayHomePage> {
  List<List<dynamic>> _csvData = [];
  int _currentIndex = 0;
  Timer? _timer;
  String _tradeLog = "";
  bool _isLoading = false;
  bool _isReplaying = false;
  String _errorMessage = "";
  double _replaySpeed = 1.0;

  Future<void> _loadCSV() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // Parse tab-delimited CSV
        List<List<dynamic>> csvTable = const CsvToListConverter(
          fieldDelimiter: '\t',
          shouldParseNumbers: true,
        ).convert(content);

        // Validate CSV structure
        if (csvTable.isEmpty || csvTable[0].length < 9) {
          throw const FormatException("CSV must have at least 9 columns");
        }

        setState(() {
          _csvData = csvTable.skip(1).where((row) => row.length >= 9).toList();
          _currentIndex = 0;
          _tradeLog = "Loaded ${_csvData.length} market data points\n";
          _isReplaying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading CSV: ${e.toString()}";
        _csvData = [];
      });
      debugPrint("CSV loading error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startReplay() {
    if (_csvData.isEmpty || _isReplaying) return;

    setState(() {
      _isReplaying = true;
      _tradeLog += "Replay started at ${_getCurrentDateTime()}\n";
    });

    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / _replaySpeed).round()),
      (timer) {
        if (_currentIndex < _csvData.length - 1) {
          setState(() => _currentIndex++);
        } else {
          _stopReplay();
          setState(() => _tradeLog += "Replay completed!\n");
        }
      },
    );
  }

  void _stopReplay() {
    _timer?.cancel();
    setState(() => _isReplaying = false);
  }

  void _resetReplay() {
    _stopReplay();
    setState(() {
      _currentIndex = 0;
      _tradeLog += "Reset to beginning\n";
    });
  }

  void _placeOrder(String type) {
    if (_csvData.isEmpty || _currentIndex >= _csvData.length) return;

    final row = _csvData[_currentIndex];
    if (row.length < 6) return; // Need at least CLOSE price (index 5)

    final price = row[5]; // CLOSE price
    setState(() {
      _tradeLog += "[${_getCurrentDateTime()}] $type at $price\n";
    });
  }

  String _getCurrentDateTime() {
    if (_currentIndex >= _csvData.length) return "";
    final row = _csvData[_currentIndex];
    return "${row[0]} ${row[1]}"; // DATE + TIME
  }

  void _changeSpeed(double speed) {
    setState(() => _replaySpeed = speed);
    if (_isReplaying) {
      _stopReplay();
      _startReplay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildMarketData() {
    if (_csvData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _errorMessage.isNotEmpty
            ? Text(_errorMessage, style: const TextStyle(color: Colors.red))
            : Text(_isLoading ? "Loading data..." : "Please load a CSV file"),
      );
    }

    if (_currentIndex >= _csvData.length) {
      return const Text("End of data reached", style: TextStyle(fontSize: 18));
    }

    final row = _csvData[_currentIndex];
    if (row.length < 6) {
      return const Text("Invalid data format",
          style: TextStyle(color: Colors.red));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(_getCurrentDateTime(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Open:", style: TextStyle(color: Colors.green)),
              Text(row[2].toString()),
              const Text("High:", style: TextStyle(color: Colors.blue)),
              Text(row[3].toString()),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Low:", style: TextStyle(color: Colors.red)),
              Text(row[4].toString()),
              const Text("Close:", style: TextStyle(color: Colors.green)),
              Text(row[5].toString()),
            ],
          ),
          const SizedBox(height: 10),
          Text("Volume: ${row[6]} | Spread: ${row[8]}"),
          Text("${_currentIndex + 1}/${_csvData.length}"),
        ],
      ),
    );
  }

  Widget _buildSpeedControls() {
    return Column(
      children: [
        Text("Speed: ${_replaySpeed}x"),
        Slider(
          min: 0.5,
          max: 5.0,
          divisions: 9,
          value: _replaySpeed,
          onChanged: _changeSpeed,
          label: "${_replaySpeed}x",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Market Replay"),
        actions: [
          if (_csvData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetReplay,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _loadCSV,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Load CSV"),
            ),
            const SizedBox(height: 20),
            Expanded(flex: 2, child: _buildMarketData()),
            const SizedBox(height: 20),
            _buildSpeedControls(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _placeOrder("BUY"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Buy"),
                ),
                ElevatedButton(
                  onPressed: () => _placeOrder("SELL"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Sell"),
                ),
                if (!_isReplaying)
                  ElevatedButton(
                    onPressed: _startReplay,
                    child: const Text("▶ Play"),
                  )
                else
                  ElevatedButton(
                    onPressed: _stopReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: Text("⏹ Stop"),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Trade Log:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(_tradeLog.isEmpty ? "No trades yet" : _tradeLog),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
