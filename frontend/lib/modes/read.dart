import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class ReadPage extends StatefulWidget {
  const ReadPage({Key? key}) : super(key: key);

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  late CameraController _cameraController;
  late TextRecognizer _textRecognizer;
  bool isDetecting = false;
  String extractedText = "No Text Detected";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTextRecognizer();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(camera, ResolutionPreset.max);

    await _cameraController.initialize();
    _startImageStream();
  }

  void _initializeTextRecognizer() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting) return;

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
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      String detectedText = recognizedText.text.isNotEmpty
          ? recognizedText.text
          : "No Text Detected";

      setState(() {
        extractedText = detectedText;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error Processing Image"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          Navigator.pop(context); // Navigate back to the homepage
        },
        child: _cameraController.value.isInitialized
            ? Stack(
                children: [
                  CameraPreview(_cameraController),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      extractedText,
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
      ),
    );
  }
}