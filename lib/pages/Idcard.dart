import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/android_ios.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class Idcard extends StatefulWidget {
  const Idcard({super.key});

  @override
  _IdcardState createState() => _IdcardState();
}

class _IdcardState extends State<Idcard> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _ninController = TextEditingController();
  final TextEditingController _cnumberController = TextEditingController();
  final TextEditingController _birthplaceController = TextEditingController();
  final TextEditingController _releasedateController = TextEditingController();
  final TextEditingController _enddateController = TextEditingController();
  final TextEditingController _backnumberController = TextEditingController();

  File? _frontImage;
  File? _backImage;
  String _extractedBirthPlace = '';
  String _extractedendDate = '';
  String _extractedReleaseDate = '';
  String _extractedNIN = '';
  String _extractedCardnumber = '';
  String _extractedNom = '';
  String _extractedPrenom = '';
  final bool _isProcessingImage = false;
  String? _processingError;
  String _extractedBirthdate = '';
  final String _extractedBacknumber = '';
  bool _isProcessing = false;
  bool _isProcessingFront = false;
  bool _isProcessingBack = false;
  bool _isVerified = false;
  String _ocrText = '';
  String? _frontIdPath;
  String? _backIdPath;
  String? _selfiePath;
  File? _selfieImage;
  DateTime? _birthDate;
  File? _extractedPhoto;
  Rect? _photoArea;
  List<File> _selfieImages = [];
  final ImagePicker _picker = ImagePicker();

  final Map<String, String> _formData = {
    'nom': '',
    'prenom': '',
    'nationalId': '',
    'birthDate': '',
  };
  List<CameraDescription>? _cameras;
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
  }

  Future<void> _pickIDCard(ImageSource source, {bool isFront = true}) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        '${isFront ? 'front' : 'back'}_id_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage =
        await File(pickedFile.path).copy('${appDir.path}/$fileName');
    await File(pickedFile.path).copy(savedImage.path);

    // Open the scanner for the selected image

    setState(() {
      if (isFront) {
        _frontImage = savedImage;
        _frontIdPath = savedImage.path;
      } else {
        _backImage = savedImage;
        _backIdPath = savedImage.path;
      }
    });

    setState(() {
      if (isFront) {
        _frontImage = File(pickedFile.path);
        _isProcessingFront = true;
      } else {
        _backImage = File(pickedFile.path);
        _isProcessingBack = true;
      }
    });

    await _processImage(File(pickedFile.path), isFront: isFront);
  }

  Future<void> _processImage(File image, {required bool isFront}) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(image.path);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      _ocrText = _normalizeText(recognizedText.text);

      if (isFront) {
        _batchFrontExtraction();
        _autoFillForm();

        // Handle image cropping with safe context
        final croppedFile = await autoCropIdPhoto(image);
        if (croppedFile != null) {
          setState(() => _extractedPhoto = croppedFile);
        }
      } else {
        _processBackOCR(recognizedText.text);
        _autoFillForm();
      }
    } catch (e) {
      setState(() => _processingError = 'OCR failed: ${e.toString()}');
    } finally {
      textRecognizer.close();
      setState(() {
        if (isFront) {
          _isProcessingFront = false;
        } else {
          _isProcessingBack = false;
        }
      });
    }
  }

  void _processFrontOCR(String text) {}

  void _processBackOCR(String text) {
    // Extract nom and prenom from back
    setState(() {
      _extractedNom = _extractNom(text);
      _extractedPrenom = _extractPrenom(text);
    });
  }

  void _batchFrontExtraction() {
    try {
      _extractNIN();
      _extractBirthdate();
      _extractCardnumber();
      _extractReleaseDate();
     
      _extractEndDate();
    } catch (e) {
      setState(
          () => _processingError = 'Data extraction error: ${e.toString()}');
    }
  }

  Future<File?> autoCropIdPhoto(File originalImage) async {
    try {
      // Step 1: Load the image
      final bytes = await originalImage.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Step 2: Initialize the face detector
      final options = FaceDetectorOptions(
        performanceMode:
            FaceDetectorMode.accurate, // Use accurate mode for better detection
        enableContours: false, // No contours needed
        enableClassification: false, // No classifications needed
      );
      final faceDetector = FaceDetector(options: options);

      // Step 3: Detect faces
      final inputImage = InputImage.fromFilePath(originalImage.path);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('No face detected in the image.');
        return null;
      }

      // Step 4: Get the largest face (most prominent)
      final face = faces
          .reduce((a, b) => a.boundingBox.width > b.boundingBox.width ? a : b);

      // Step 5: Calculate crop area with padding
      const padding = 0.3; // 30% padding around the face
      final rect = face.boundingBox;
      final expandedRect = Rect.fromLTWH(
        rect.left - rect.width * padding,
        rect.top - rect.height * padding,
        rect.width * (1 + 2 * padding),
        rect.height * (1 + 2 * padding),
      );

      // Step 6: Crop the image
      final cropped = img.copyCrop(
        image,
        x: expandedRect.left.toInt(),
        y: expandedRect.top.toInt(),
        width: expandedRect.width.toInt(),
        height: expandedRect.height.toInt(),
      );

      // Step 7: Save the cropped image
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/cropped_face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return File(path)..writeAsBytesSync(img.encodeJpg(cropped));
    } catch (e) {
      debugPrint('Face detection and cropping failed: $e');
      return null;
    } finally {
      // Close the face detector
    }
  }

  void _extractNIN() {
    String? nin;

    // Pattern 1: Direct keyword match
    const keywords = [
      'رقم التعريف الوطني',
      'الوطني التعريف رقم',
      'national identification number',
      'nin'
    ];

    // Search for keyword patterns
    for (final keyword in keywords) {
      final index = _ocrText.indexOf(keyword);
      if (index != -1) {
        final textAfter = _ocrText.substring(index + keyword.length);
        final match = RegExp(r'\d{18}').firstMatch(textAfter);
        if (match != null) {
          nin = match.group(0);
          break;
        }
      }
    }

    // Pattern 2: Standalone 18-digit number (fallback)
    if (nin == null) {
      final matches = RegExp(r'\b\d{18}\b').allMatches(_ocrText);
      if (matches.isNotEmpty) {
        nin = matches.first.group(0);
      }
    }

    setState(() => _extractedNIN = nin ?? '');

    if (_extractedNIN.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NIN not found. Try better quality image')),
      );
      debugPrint('OCR Text:\n$_ocrText'); // For debugging
    }
  }

  void _extractBirthdate() {
    String? birthdate;

    // Debug: Print OCR text
    debugPrint('Extracted OCR Text:\n$_ocrText');

    // Match all date formats in the OCR text
    final matches = RegExp(r'(\d{4}[./-]\d{2}[./-]\d{2})').allMatches(_ocrText);

    // Debug: Print all matched dates
    debugPrint('All matched dates: ${matches.map((m) => m.group(0)).toList()}');

    // Extract the last date (birthdate)
    if (matches.isNotEmpty) {
      birthdate = matches.last.group(0); // Get the last matched date
      debugPrint('Extracted Birthdate: $birthdate');
    }

    // Update UI state
    setState(() => _extractedBirthdate = birthdate ?? '');

    // Debug: Show error message if no birthdate found
    if (_extractedBirthdate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Birthdate not found. Try a better quality image')),
      );
      debugPrint('Birthdate NOT FOUND!');
    }
  }

  void _extractEndDate() {
    String? enddate;

    // Debug: Print OCR text
    debugPrint('Extracted OCR Text:\n$_ocrText');

    // Match all dates in the OCR text
    final dateMatches =
        RegExp(r'(\d{4}[./-]\d{2}[./-]\d{2})').allMatches(_ocrText);
    final dates = dateMatches.map((m) => m.group(0)).toList();

    // Debug: Print all dates
    debugPrint('All Dates Found: $dates');

    // Check if there are at least two dates
    if (dates.length >= 2) {
      enddate = dates[1]; // Second date (index 1)
      debugPrint('Extracted Issue Date: $enddate');
    }

    // Update UI state
    setState(() => _extractedendDate = enddate ?? '');

    // Show error if no date found
    if (_extractedendDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Issue Date not found. Try a better quality image')),
      );
      debugPrint('Issue Date NOT FOUND!');
    }
  }

  void _extractReleaseDate() {
    String? releasedate;

    // Pattern 1: Direct keyword match
    const keywords = ['تاريخ الاصدار'];

    // Search for keyword patterns
    for (final keyword in keywords) {
      final index = _ocrText.indexOf(keyword);
      if (index != -1) {
        final textAfter = _ocrText.substring(index + keyword.length);
        final match =
            RegExp(r'(\d{4}[./-]\d{2}[./-]\d{2})').firstMatch(textAfter);
        if (match != null) {
          releasedate = match.group(0);
          break;
        }
      }
    }

    // Pattern 2: Standalone 18-digit number (fallback)
    if (releasedate == null) {
      final matches =
          RegExp(r'(\d{4}[./-]\d{2}[./-]\d{2})').allMatches(_ocrText);
      if (matches.isNotEmpty) {
        releasedate = matches.first.group(0);
      }
    }

    setState(() => _extractedReleaseDate = releasedate ?? '');

    if (_extractedReleaseDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Release Date not found. Try better quality image')),
      );
      debugPrint('OCR Text:\n$_ocrText'); // For debugging
    }
  }

  void _extractCardnumber() {
    String? cnumber;

    // Pattern 1: Direct keyword match
    const keywords = ['بطاقة التعريف الوطنية'];

    // Search for keyword patterns
    for (final keyword in keywords) {
      final index = _ocrText.indexOf(keyword);
      if (index != -1) {
        final textAfter = _ocrText.substring(index + keyword.length);
        final match = RegExp(r'\d{9}').firstMatch(textAfter);
        if (match != null) {
          cnumber = match.group(0);
          break;
        }
      }
    }

    // Pattern 2: Standalone 18-digit number (fallback)
    if (cnumber == null) {
      final matches = RegExp(r'\b\d{9}\b').allMatches(_ocrText);
      if (matches.isNotEmpty) {
        cnumber = matches.first.group(0);
      }
    }

    setState(() => _extractedCardnumber = cnumber ?? '');

    if (_extractedCardnumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Card number not found. Try better quality image')),
      );
      debugPrint('OCR Text:\n$_ocrText'); // For debugging
    }
  }



  String _extractNom(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      if (line.toLowerCase().startsWith('nom:')) {
        return line.substring(4).trim();
      }
    }
    return '';
  }

  String _extractPrenom(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      if (line.toLowerCase().startsWith('prénom(s):')) {
        return line.substring(10).trim();
      }
    }
    return '';
  }

  String _normalizeText(String text) {
    // Clean text for better processing
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse whitespace
        .replaceAll(RegExp(r'[٫,_-]'), '') // Remove common separators
        .toLowerCase();
  }

  String _normalizeName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ') // Enlève les espaces multiples
        .replaceAll(RegExp(r'[^\wàâçéèêëîïôûùüÿñæœ]'),
            ''); // Garde les caractères spéciaux français
  }

  //Future<void> _takeSelfie() async {
  // final picker = ImagePicker();
  // final image = await picker.pickImage(source: ImageSource.camera);
  //if (image != null) {
  //  setState(() => _selfiePath = image.path);
  //  }
  //}

  Future<void> _takeSelfie() async {
    final XFile? imageFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (imageFile == null) return;

    File image = File(imageFile.path);
    final face = await _detectFace(image);

    if (face != null) {
      final croppedFace = await _cropFace(image, face);
      if (croppedFace != null) {
        setState(() => _selfiePath = croppedFace.path);
      }
    }
  }

  Future<Face?> _detectFace(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true, // Enable eye open/closed detection
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final List<Face> faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();

    if (faces.isEmpty) {
      _showErrorDialog(
          "No face detected. Make sure your face is visible and well-lit.");
      return null;
    }

    if (faces.length != 1) {
      _showErrorDialog(
          "Multiple faces detected. Ensure only your face is in the frame.");
      return null;
    }

    Face face = faces.first;

    // **Check Lighting Condition**

    // **Check for Blurry Image**

    // **Check if Eyes Are Open**
    if (face.leftEyeOpenProbability != null &&
        face.rightEyeOpenProbability != null) {
      if (face.leftEyeOpenProbability! < 0.3 &&
          face.rightEyeOpenProbability! < 0.3) {
        _showErrorDialog(
            "Your eyes are closed. Please open them and try again.");
        return null;
      }
    }

    // **Check Head Alignment**
    if (face.headEulerAngleY != null && (face.headEulerAngleY!.abs() > 10)) {
      _showErrorDialog(
          "Keep your head straight and look directly at the camera.");
      return null;
    }

    if (face.headEulerAngleZ != null && (face.headEulerAngleZ!.abs() > 10)) {
      _showErrorDialog("Please avoid tilting your head.");
      return null;
    }

    return face;
  }

  Future<File?> _cropFace(File imageFile, Face face) async {
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) return null;

    final rect = face.boundingBox;

    // Define padding percentage (adjust as needed)
    double paddingFactor = 0.4; // 40% larger area around face

    // Calculate new dimensions with padding
    int newX = (rect.left - rect.width * paddingFactor)
        .toInt()
        .clamp(0, originalImage.width);
    int newY = (rect.top - rect.height * paddingFactor)
        .toInt()
        .clamp(0, originalImage.height);
    int newWidth = (rect.width * (1 + 2 * paddingFactor))
        .toInt()
        .clamp(0, originalImage.width - newX);
    int newHeight = (rect.height * (1 + 2 * paddingFactor))
        .toInt()
        .clamp(0, originalImage.height - newY);

    // Crop the image with adjusted dimensions
    img.Image cropped = img.copyResize(
      img.copyCrop(originalImage,
          x: newX, y: newY, width: newWidth, height: newHeight),
      width: 300, // Resize to fixed dimensions
      height: 300,
    );

    // Save cropped image
    final croppedFile = File(imageFile.path.replaceAll('.jpg', '_cropped.jpg'))
      ..writeAsBytesSync(img.encodeJpg(cropped));
    return croppedFile;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = DateFormat('yyyy.MM.dd').format(picked);
        _formData['birthDate'] = _birthDateController.text;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frontIdPath == null || _backIdPath == null || _selfiePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez uploader toutes les images')),
      );
      return;
    }

    if (_extractedNIN.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please process ID card first')),
      );
      return;
    }
    final errors = <String>[];

    if (_normalizeName(_nomController.text) != _normalizeName(_extractedNom)) {
      errors.add('Nom mismatch');
    }
    if (_normalizeName(_prenomController.text) !=
        _normalizeName(_extractedPrenom)) {
      errors.add('Prenom mismatch');
    }
    if (_ninController.text != _extractedNIN) errors.add('NIN mismatch');
    if (_birthDateController.text != _extractedBirthdate) {
      errors.add('Birthdate mismatch');
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join(', '))),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.1.12:3000/submit-form'));

      // Add text fields
      request.fields.addAll({
        'nom': _formData['nom']!,
        'prenom': _formData['prenom']!,
        'nationalId': _formData['nationalId']!,
        'birthDate': _formData['birthDate']!,
      });

      // Add files with error handling
      try {
        request.files.add(
            await http.MultipartFile.fromPath('frontidCard', _frontIdPath!));
        request.files
            .add(await http.MultipartFile.fromPath('backidCard', _backIdPath!));
        request.files
            .add(await http.MultipartFile.fromPath('selfie', _selfiePath!));

        setState(() => _isVerified = true);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data verified and saved successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: ${e.toString()}')),
        );
      }

      // Show loading indicator

      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      final responseData = jsonDecode(respStr);
      Navigator.pop(context); // Hide loading

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form submitted successfully')));
      } else if (response.statusCode == 400 &&
          responseData['error'] == 'NIN déjà enregistré') {
        // Cas spécifique du NIN existant
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Ce NIN est déjà enregistré dans notre système'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      Navigator.pop(context); // Hide loading on error
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: ${e.toString()}')));
    }
  }

  void _autoFillForm() {
    setState(() {
      _nomController.text = _extractedNom;
      _prenomController.text = _extractedPrenom;
      _ninController.text = _extractedNIN;
      _cnumberController.text = _extractedCardnumber;
      _birthDateController.text = _extractedBirthdate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Id Card Form')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your last name' : null,
                onChanged: (value) => _formData['nom'] = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _prenomController,
                decoration: const InputDecoration(
                  labelText: 'Prenom',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your first name' : null,
                onChanged: (value) => _formData['prenom'] = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _ninController,
                decoration: const InputDecoration(
                  labelText: 'Numero identite',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 18,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter NIN';
                  }
                  if (value.length != 18) {
                    return 'NIN must be 18 digits';
                  }
                  return null;
                },
                onChanged: (value) => _formData['nationalId'] = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _cnumberController,
                decoration: const InputDecoration(
                  labelText: 'Numero de la carte',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 9,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Card Number';
                  }
                  if (value.length != 9) {
                    return 'Card number must be 9 digits';
                  }
                  return null;
                },
                onChanged: (value) => _formData['card_number'] = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(
                  labelText: 'Date de naissance',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _selectDate(context),
                validator: (value) =>
                    value!.isEmpty ? 'Please select birth date' : null,
                onChanged: (value) => _formData['birthdate'] = value,
              ),
              SizedBox(height: 20),
              if (_extractedPhoto != null)
                Column(
                  children: [
                    const SizedBox(height: 20),
                    Text('Extracted ID Photo:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Image.file(_extractedPhoto!, height: 150),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: _takeSelfie,
                          child: Text("Take Selfie"),
                        ),
                        if (_selfiePath != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.file(File(_selfiePath!),
                                width: 100, height: 100, fit: BoxFit.cover),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildUploadSection(
                title: 'Front ID Card',
                image: _frontImage,
                isProcessing: _isProcessingFront,
                onTap: () => _pickIDCard(ImageSource.gallery, isFront: true),
                extractedInfo: [
                  _buildComparison('NIN', _extractedNIN, _ninController.text),
                  _buildComparison('Birthdate', _extractedBirthdate,
                      _birthDateController.text),
                  _buildComparison('Card number', _extractedCardnumber,
                      _cnumberController.text),
                  // _buildComparison('Birthdate Place', _extractedBirthPlace,
                  //  _birthplaceController.text),
                //  _buildComparison('Release Date', _extractedReleaseDate,
                   //   _releasedateController.text),
                  _buildComparison(
                      'End Date', _extractedendDate, _enddateController.text),
                ],
              ),

              // Back ID Section
              _buildUploadSection(
                title: 'Back ID Card',
                image: _backImage,
                isProcessing: _isProcessingBack,
                onTap: () => _pickIDCard(ImageSource.gallery, isFront: false),
                extractedInfo: [
                  _buildComparison('Nom', _extractedNom, _nomController.text),
                  _buildComparison(
                      'Prénom', _extractedPrenom, _prenomController.text),
                ],
              ),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required File? image,
    required bool isProcessing,
    required VoidCallback onTap,
    required List<Widget> extractedInfo,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: image != null
                    ? Image.file(image, fit: BoxFit.cover)
                    : Icon(Icons.upload, size: 40),
              ),
            ),
            if (isProcessing) LinearProgressIndicator(),
            ...extractedInfo,
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(String label, String extracted, String entered) {
    final isMatch =
        extracted.isNotEmpty && entered.isNotEmpty && extracted == entered;
    return ListTile(
      title: Text('$label: ${extracted.isEmpty ? 'Not found' : extracted}'),
      trailing: Icon(
        isMatch ? Icons.check_circle : Icons.error,
        color: isMatch ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _birthDateController.dispose();
    _ninController.dispose();
    _cnumberController.dispose();
    _birthplaceController.dispose();
    _releasedateController.dispose();
    _enddateController.dispose();

    super.dispose();
  }
}
