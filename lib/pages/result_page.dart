import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import '../utils/error_handler.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic>? result;

  const ResultPage({super.key, required this.result});

  static String? selfiePath = null;
  static String? imagePath = null;

  @override
  State<ResultPage> createState() => widgetPageState();
}

class widgetPageState extends State<ResultPage> {

  ValueNotifier<bool?> isIdentityVerified = ValueNotifier<bool?>(null);

  @override
  initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async{
      await uploadAndCompareFaces();
      // await extractArabicText();
    });
  }

  Future<void> uploadAndCompareFaces() async {
    try {
      if (ResultPage.imagePath == null || ResultPage.selfiePath == null) {
        print("Please upload both images.");
        return;
      }

      final responseData = await ServerErrorHandler.sendRequest(
        endpoint: '/compare-faces',
        fields: {},
        files: [
          {
            'fieldName': 'idCardFace',
            'filePath': ResultPage.imagePath!,
          },
          {
            'fieldName': 'selfie',
            'filePath': ResultPage.selfiePath!,
          },
        ],
        context: context,
        successMessage: 'Face comparison completed!',
      );

      final String message = responseData['message'] ?? 'No message';
      final bool isVerified = responseData['verified'] ?? false;

      setState(() {
        isIdentityVerified.value = isVerified;
      });
    } catch (e) {
      print('Error during face comparison: $e');
      setState(() {
        isIdentityVerified.value = false;
      });
    }
  }

  Future<void> extractArabicText() async {
    try {
      if (ResultPage.imagePath == null) {
        print("Please upload an image.");
        return;
      }

      final responseData = await ServerErrorHandler.sendRequest(
        endpoint: '/extract-text',
        fields: {},
        files: [
          {
            'fieldName': 'image',
            'filePath': ResultPage.imagePath!,
          },
        ],
        context: context,
        successMessage: 'Text extraction completed!',
      );

      final String message = responseData['message'] ?? 'No message';
      final bool isVerified = responseData['verified'] ?? false;

      setState(() {
        isIdentityVerified.value = isVerified;
      });
    } catch (e) {
      print('Error during text extraction: $e');
      setState(() {
        isIdentityVerified.value = false;
      });
    }
  }

  Future<String> convertToJpeg(String image) async {
    try {
      final responseData = await ServerErrorHandler.sendSimpleRequest(
        endpoint: '/convert',
        data: jsonEncode({'jp2_base64': image}),
        context: context,
        successMessage: 'Image converted successfully!',
      );

      return responseData.toString().split("\"")[1];
    } catch (e) {
      print('Convert Error: $e');
      return "";
    }
  }

  Widget _buildPhoto() {
    final isJpeg = widget.result?['dg2']["isJpeg"];
    final base64Photo = widget.result?['dg2']["photo"];

    if (!isJpeg) {
      return FutureBuilder<String>(
        future: convertToJpeg(base64Photo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Container(
              width: 160,
              height: 200,
              child: Image.memory(base64Decode(base64Photo.trim())),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final decoded = base64Decode(snapshot.data!.trim());
            return Container(
              width: 160,
              height: 200,
              child: Image.memory(decoded),
            );
          } else {
            return const Text("❌ Invalid image data");
          }
        },
      );
    }

    // Already JPEG — render directly
    return Container(
      width: 160,
      height: 200,
      child: Image.memory(base64Decode(base64Photo.trim())),
    );
  }


  Widget _buildResultCard(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value?.toString() ?? "Unknown"),
      ),
    );
  }

  Widget _buildResultDetails() {
    if (widget.result == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildPhoto(),
            // add icon to show identity verification status
            isIdentityVerified.value == null ? Container() : Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    isIdentityVerified.value! ? Icons.check_circle : Icons.error,
                    color: isIdentityVerified.value! ? Colors.green : Colors.red,
                    size: 100,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text("Pesonal Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("Full Name",
            "${widget.result!['dg1']["firstName"]} ${widget.result!['dg1']["lastName"]} \n${widget.result!["dg11"]['arabicName']}"),
        _buildResultCard("Given names",
            "${widget.result!['dg1']["firstName"]}, ${widget.result!['dg11']["nameOfHolder"]}"),
        _buildResultCard("Name", "${widget.result!['dg1']["lastName"]}"),
        _buildResultCard("Gender", widget.result!['dg1']["gender"]),
        _buildResultCard(
            "Other Information", widget.result!["dg11"]['otherInfo']),
        _buildResultCard("Nationality", widget.result!['dg1']["nationality"]),
        _buildResultCard(
            "Date of Birth", widget.result!["dg11"]["fullDateOfBirth"]),
        _buildResultCard(
            "Place of Birth", widget.result!["dg11"]["placeOfBirth"]),
        if (widget.result!["dg11"]["custodian"] == null ||
            widget.result!["dg11"]["custodian"] == "")
          _buildResultCard(
              "Custodian", widget.result!["dg11"]["custodyInformation"])
        else
          _buildResultCard("Custodian", widget.result!["dg11"]["custodian"]),
        _buildResultCard("National Identification Number",
            widget.result!["dg11"]["personalNumber"]),
        const SizedBox(
          height: 20,
        ),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Document Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard(
            "Document Code", widget.result!['dg1']["documentCode"]),
        _buildResultCard(
            "Document Number", widget.result!['dg1']["documentNumber"]),
        _buildResultCard(
            "Issuing Country", widget.result!['dg1']["issuingState"]),
        const SizedBox(
          height: 20,
        ),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Chip Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("LDS Version", widget.result!['com']["ldsVersion"]),
        _buildResultCard(
            "Unicode Version", widget.result!['com']["unicodeVersion"]),
        _buildResultCard(
            "Data groups", widget.result!['com']["tagsList"].toString()),
        const SizedBox(
          height: 20,
        ),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Document Signing Certificate",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard(
            "Serial Number", widget.result!["sod"]['serialNumber']),
        _buildResultCard("Signature algorithm",
            widget.result!["sod"]['Signature algorithm']),
        _buildResultCard("Public Key Algorithm",
            widget.result!["sod"]['Public Key'].split(" ")[0]),
        _buildResultCard("Issuer", widget.result!["sod"]['issuer']),
        // _buildResultCard("Signature Thumbprint", widget.result!["docSigningCert"]['issuer']),
        _buildResultCard("Subject", widget.result!["sod"]['Subject']),
        _buildResultCard("Valid from", widget.result!["sod"]['Valid from']),
        _buildResultCard("Valid to", widget.result!["sod"]['Valid until']),
        _buildResultCard(
            "Signature", base64Encode(widget.result!["sod"]['signature'])),
        _buildResultCard("Version", widget.result!["sod"]['version']),
        const SizedBox(
          height: 20,
        ),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Country Signing Certificate",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard(
            "Serial Number", widget.result!["sod"]['serialNumber']),
        _buildResultCard("Signature algorithm",
            widget.result!["sod"]['Signature algorithm']),
        _buildResultCard("Public Key Algorithm",
            widget.result!["sod"]['Public Key'].split(" ")[0]),
        _buildResultCard("Issuer", widget.result!["sod"]['issuer']),
        // _buildResultCard("Signature Thumbprint", widget.result!["docSigningCert"]['issuer']),
        _buildResultCard("Subject", widget.result!["sod"]['Subject']),
        _buildResultCard("Valid from", widget.result!["sod"]['Valid from']),
        _buildResultCard("Valid to", widget.result!["sod"]['Valid until']),
        _buildResultCard(
            "Signature", base64Encode(widget.result!["sod"]['signature'])),
        _buildResultCard("Version", widget.result!["sod"]['version']),
        const SizedBox(
          height: 20,
        ),
        // Divider(thickness: 1, color: Colors.grey[300]),
        // Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        // _buildResultCard("Digest Algorithm", widget.result!["digestAlgorithm"]),
        // _buildResultCard("Digest Algorithm Signer info", widget.result!["digestAlgorithmSignerInfo"]),
        // _buildResultCard("Unicode Version", widget.result!["unicodeVersion"]),
        // _buildResultCard("Public Key algorithm", widget.result!["publicKey"]['algorithm']),
        // _buildResultCard("Public Key Format", widget.result!["publicKey"]['format']),
        // _buildResultCard("Public key encoded", widget.result!["publicKey"]['encoded']),
        const SizedBox(
          height: 20,
        ),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Signature",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Image.memory(
          Uint8List.fromList(base64Decode(widget.result!['dg7']["images"][0])),
          fit: BoxFit.cover,
        ),
        const SizedBox(
          height: 20,
        ),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("MRZ from chip",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("", widget.result!['dg1']["fullMrz"]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Document Information"),
        centerTitle: true,
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildResultDetails(),
          ),
        ),
      ),
    );
  }
}
