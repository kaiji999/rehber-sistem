import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

class WalkPage extends StatefulWidget {
  const WalkPage({Key? key}) : super(key: key);

  @override
  _WalkPageState createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  late CameraController _cameraController;
  late ImageLabeler _imageLabeler;
  late FlutterTts _flutterTts;
  bool isDetecting = false;
  bool isSpeaking = false;
  String result = "Hiçbir nesne algılanmadı";
  Map<String, String> labelTranslations = {};

  @override
  void initState() {
    super.initState();
    _loadLabelTranslations();
    _initializeCamera();
    _initializeImageLabeler();
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _loadLabelTranslations() async {
    final labelsFile = await DefaultAssetBundle.of(
      context,
    ).loadString('lib/assets/labels_tr.txt');
    final lines = labelsFile.split('\n');
    final Map<String, String> translations = {};
    for (var line in lines) {
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

  void _initializeImageLabeler() {
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    _imageLabeler = ImageLabeler(options: options);
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting || isSpeaking) return;

      isDetecting = true;
      await _processImage(image);
      isDetecting = false;
    });
  }

  Future<void> _processImage(CameraImage cameraImage) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File imageFile = File(filePath);

      final XFile picture = await _cameraController.takePicture();
      await picture.saveTo(imageFile.path);

      final inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> labels = await _imageLabeler.processImage(
        inputImage,
      );
      double threshold = 0.1;

      final filteredLabels =
          labels.where((label) => label.confidence >= threshold).toList();
      String detectedObjects =
          filteredLabels.isNotEmpty
              ? filteredLabels
                  .where(
                    (label) => labelTranslations.containsKey(
                      label.label.toLowerCase(),
                    ),
                  )
                  .map((label) {
                    final key = label.label.toLowerCase();
                    final tr = labelTranslations[key];
                    return "${tr!} - ${(label.confidence * 100).toStringAsFixed(2)}%";
                  })
                  .join("\n")
              : "Hiçbir nesne tespit edilmedi";

      setState(() {
        result = detectedObjects;
      });

      // Speak the detected objects
      if (detectedObjects != "Hiçbir nesne algılanmadı") {
        isSpeaking = true;
        await _flutterTts.speak(result);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    _imageLabeler.close();
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
