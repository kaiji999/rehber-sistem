import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

class WalkPage extends StatefulWidget {
  const WalkPage({Key? key}) : super(key: key);

  @override
  _WalkPageState createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  late CameraController _cameraController;
  late ImageLabeler _baseLabeler;
  late FlutterTts _flutterTts;
  bool isDetecting = false;
  bool isSpeaking = false;
  String result = "Hiçbir nesne algılanmadı";
  Map<String, String> labelTranslations = {};

  final String _labelsTrPath = 'lib/assets/labels_tr.txt';

  @override
  void initState() {
    super.initState();
    _loadLabelTranslations();
    _initializeCamera();
    _initializeLabeler();
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
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

  Future<void> _initializeLabeler() async {
    _baseLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
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

      // Format results: only show translated labels
      String detectedObjects = "";
      if (baseLabels.isNotEmpty) {
        final translated = baseLabels
            .map((label) {
              final key = label.label.toLowerCase();
              final tr = labelTranslations[key];
              return tr != null
                  ? "$tr - ${(label.confidence * 100).toStringAsFixed(2)}%"
                  : null;
            })
            .where((e) => e != null)
            .join("\n");
        if (translated.isNotEmpty) {
          detectedObjects = translated;
        }
      }

      if (detectedObjects.trim().isEmpty) {
        detectedObjects = "Hiçbir nesne tespit edilmedi";
      }

      setState(() {
        result = detectedObjects;
      });

      // Speak the detected objects (Turkish only)
      if (detectedObjects != "Hiçbir nesne tespit edilmedi" &&
          detectedObjects != "Hiçbir nesne algılanmadı") {
        isSpeaking = true;
        final speakText =
            baseLabels
                .map((label) {
                  final key = label.label.toLowerCase();
                  return labelTranslations[key];
                })
                .where((e) => e != null)
                .join(", ") +
            ".";
        if (speakText.trim().isNotEmpty) {
          await _flutterTts.speak(speakText);
        }
      }
    } catch (error) {
      print(error); // Print the error for debugging
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
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
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yürüme Modu')),
      body:
          _cameraController.value.isInitialized
              ? GestureDetector(
                onDoubleTap: () {
                  Navigator.of(context).pop(); // Anasayfaya döner
                },
                child: Stack(
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
                ),
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
