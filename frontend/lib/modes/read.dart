import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReadPage extends StatefulWidget {
  const ReadPage({Key? key}) : super(key: key);

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  late CameraController _cameraController;
  late TextRecognizer _textRecognizer;
  late FlutterTts _flutterTts;
  bool isProcessing = false;
  String extractedText = "Ekrana dokunun, metin algılansın.";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTextRecognizer();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("tr-TR");
    _flutterTts.speak("Ekrana dokunun, metin algılansın.");
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(camera, ResolutionPreset.max);

    await _cameraController.initialize();
    setState(() {});
  }

  void _initializeTextRecognizer() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  Future<void> _captureAndProcessImage() async {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      extractedText = "Metin algılanıyor...";
    });
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File imageFile = File(filePath);

      final XFile picture = await _cameraController.takePicture();
      await picture.saveTo(imageFile.path);

      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String detectedText =
          recognizedText.text.isNotEmpty
              ? recognizedText.text
              : "Metin algılanamadı.";

      setState(() {
        extractedText = detectedText;
      });

      // Speak the detected text
      if (detectedText != "Metin algılanamadı.") {
        await _flutterTts.setLanguage("tr-TR");
        await _flutterTts.speak(detectedText);
      }
    } catch (error) {
      setState(() {
        extractedText = "Bir hata oluştu.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Görüntü işleme hatası"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _captureAndProcessImage,
        onDoubleTap: () {
          Navigator.pop(context); // Navigate back to the homepage
        },
        child:
            _cameraController.value.isInitialized
                ? Stack(
                  children: [
                    CameraPreview(_cameraController),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: SingleChildScrollView(
                        child: Text(
                          extractedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            backgroundColor: Colors.black54,
                          ),
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
