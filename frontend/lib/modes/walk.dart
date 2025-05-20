import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

class WalkPage extends StatefulWidget {
  const WalkPage({Key? key}) : super(key: key);

  @override
  _WalkPageState createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  late CameraController _cameraController;
  late ImageLabeler _baseLabeler;
  late ImageLabeler _customLabeler;
  late FlutterTts _flutterTts;
  bool isDetecting = false;
  bool isSpeaking = false;
  String result = "Hiçbir nesne algılanmadı";
  List<String> customLabels = [];
  Map<String, String> labelTranslations = {};

  final String _modelPath = 'lib/assets/model/son_model.tflite';
  final String _labelsPath = 'lib/assets/model/labels.txt';
  final String _labelsTrPath = 'lib/assets/labels_tr.txt';

  @override
  void initState() {
    super.initState();
    _loadCustomLabels();
    _loadLabelTranslations();
    _initializeCamera();
    _initializeLabelers();
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _loadCustomLabels() async {
    final labelsFile = await rootBundle.loadString(_labelsPath);
    setState(() {
      customLabels =
          labelsFile
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .toList();
    });
  }

  Future<void> _loadLabelTranslations() async {
    final trFile = await rootBundle.loadString(_labelsTrPath);
    final Map<String, String> translations = {};
    for (var line in trFile.split('\n')) {
      if (line.trim().isEmpty || !line.contains('=')) continue;
      final parts = line.split('=');
      if (parts.length == 2) {
        translations[parts[0].trim().toLowerCase()] = parts[1].trim();
      }
    }
    setState(() {
      labelTranslations = translations;
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    await _cameraController.initialize();
    _startImageStream();
  }

  Future<void> _initializeLabelers() async {
    _baseLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    final modelPath = await _getAssetPath(_modelPath);
    _customLabeler = ImageLabeler(
      options: LocalLabelerOptions(
        modelPath: modelPath,
        confidenceThreshold: 0.5,
      ),
    );
  }

  Future<String> _getAssetPath(String asset) async {
    final directory = await getApplicationSupportDirectory();
    final path = '${directory.path}/${basename(asset)}';
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(asset);
      await file.create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return file.path;
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting || isSpeaking) return;
      isDetecting = true;
      await _processImage();
      isDetecting = false;
    });
  }

  Future<void> _processImage() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File imageFile = File(filePath);

      final XFile picture = await _cameraController.takePicture();
      await picture.saveTo(imageFile.path);

      final inputImage = InputImage.fromFile(imageFile);

      // Base model: image labeler
      final List<ImageLabel> baseLabels = await _baseLabeler.processImage(
        inputImage,
      );

      // Custom model: image labeler
      final List<ImageLabel> customLabelsResult = await _customLabeler
          .processImage(inputImage);

      // Format results
      String detectedObjects = "";

      // Base model results (with Turkish translation)
      if (baseLabels.isNotEmpty) {
        detectedObjects +=
            "Varsayılan Model:\n" +
            baseLabels
                .map((label) {
                  final key = label.label.toLowerCase();
                  final tr = labelTranslations[key];
                  return "${tr ?? label.label} - ${(label.confidence * 100).toStringAsFixed(2)}%";
                })
                .join("\n") +
            "\n";
      }

      // Custom model results (no translation)
      if (customLabelsResult.isNotEmpty) {
        detectedObjects +=
            "Özel Model:\n" +
            customLabelsResult
                .map((label) {
                  final idx = label.index;
                  final customLabel =
                      (idx < customLabels.length)
                          ? customLabels[idx]
                          : label.label;
                  return "$customLabel - ${(label.confidence * 100).toStringAsFixed(2)}%";
                })
                .join("\n") +
            "\n";
      }

      if (detectedObjects.trim().isEmpty) {
        detectedObjects = "Hiçbir nesne tespit edilmedi";
      }

      setState(() {
        result = detectedObjects;
      });

      // Speak the detected objects (Turkish for base model)
      if (detectedObjects != "Hiçbir nesne tespit edilmedi" &&
          detectedObjects != "Hiçbir nesne algılanmadı") {
        isSpeaking = true;
        String speakText = "";
        if (baseLabels.isNotEmpty) {
          speakText +=
              baseLabels
                  .map((label) {
                    final key = label.label.toLowerCase();
                    return labelTranslations[key] ?? label.label;
                  })
                  .join(", ") +
              ". ";
        }
        if (customLabelsResult.isNotEmpty) {
          speakText +=
              customLabelsResult
                  .map((label) {
                    final idx = label.index;
                    return (idx < customLabels.length)
                        ? customLabels[idx]
                        : label.label;
                  })
                  .join(", ") +
              ". ";
        }
        await _flutterTts.speak(speakText);
      }
    } catch (error) {
      print(error); // Print the error for debugging
      if (!mounted) return;
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text("Görüntü işleme hatası"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _baseLabeler.close();
    _customLabeler.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yürüme Modu')),
      body:
          _cameraController.value.isInitialized
              ? Stack(
                children: [
                  CameraPreview(_cameraController),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      result,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
