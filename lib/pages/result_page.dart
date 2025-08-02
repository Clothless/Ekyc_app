import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

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

class widgetPageState extends State<ResultPage> with TickerProviderStateMixin {
  ValueNotifier<bool?> isIdentityVerified = ValueNotifier<bool?>(null);
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _bounceController;
  late AnimationController _scaleController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _scaleAnimation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.linear,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
    _bounceController.forward();
    _scaleController.forward();

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await uploadAndCompareFaces();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _bounceController.dispose();
    _scaleController.dispose();
    super.dispose();
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
        data: {'jp2_base64': image},
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
            return AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotateAnimation.value * 2 * math.pi,
                  child: Container(
                    width: 160,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.shade200,
                          Colors.indigo.shade100,
                          Colors.indigo.shade200,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.indigo.shade600,
                      ),
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Container(
              width: 160,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade400, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.memory(base64Decode(base64Photo.trim())),
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final decoded = base64Decode(snapshot.data!.trim());
            return Container(
              width: 160,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.memory(decoded, fit: BoxFit.cover),
              ),
            );
          } else {
            return Container(
              width: 160,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade400, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 50),
                  SizedBox(height: 12),
                  Text(
                    "Invalid image",
                    style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
        },
      );
    }

    // Already JPEG — render directly
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Image.memory(base64Decode(base64Photo.trim()), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildResultCard(String label, dynamic value, {Color? color}) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_bounceAnimation.value * 0.2),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (color ?? Colors.indigo).withOpacity(0.15),
                  (color ?? Colors.indigo).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (color ?? Colors.indigo).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (color ?? Colors.indigo).withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (color ?? Colors.indigo).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: (color ?? Colors.indigo).withOpacity(0.8),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (color ?? Colors.indigo).withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (color ?? Colors.indigo).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      value?.toString() ?? "Unknown",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_scaleAnimation.value * 0.1),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 20, horizontal: 6),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (color ?? Colors.indigo).withOpacity(0.25),
                  (color ?? Colors.indigo).withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: (color ?? Colors.indigo).withOpacity(0.4),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (color ?? Colors.indigo).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (color ?? Colors.indigo).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: (color ?? Colors.indigo).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: (color ?? Colors.indigo).withOpacity(0.8),
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: (color ?? Colors.indigo).withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationStatus() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isIdentityVerified.value == true 
                      ? Colors.green.shade200 
                      : isIdentityVerified.value == false 
                          ? Colors.red.shade200 
                          : Colors.orange.shade200,
                  isIdentityVerified.value == true 
                      ? Colors.green.shade100 
                      : isIdentityVerified.value == false 
                          ? Colors.red.shade100 
                          : Colors.orange.shade100,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isIdentityVerified.value == true 
                    ? Colors.green.shade400 
                    : isIdentityVerified.value == false 
                        ? Colors.red.shade400 
                        : Colors.orange.shade400,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isIdentityVerified.value == true 
                      ? Colors.green 
                      : isIdentityVerified.value == false 
                          ? Colors.red 
                          : Colors.orange).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isIdentityVerified.value == true 
                        ? Icons.verified_user 
                        : isIdentityVerified.value == false 
                            ? Icons.error_outline 
                            : Icons.pending,
                    color: isIdentityVerified.value == true 
                        ? Colors.green.shade700 
                        : isIdentityVerified.value == false 
                            ? Colors.red.shade700 
                            : Colors.orange.shade700,
                    size: 70,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  isIdentityVerified.value == true 
                      ? "Identity Verified" 
                      : isIdentityVerified.value == false 
                          ? "Identity Not Verified" 
                          : "Verifying Identity...",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isIdentityVerified.value == true 
                        ? Colors.green.shade800 
                        : isIdentityVerified.value == false 
                            ? Colors.red.shade800 
                            : Colors.orange.shade800,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    isIdentityVerified.value == true 
                        ? "Face comparison successful" 
                        : isIdentityVerified.value == false 
                            ? "Face comparison failed" 
                            : "Processing face comparison...",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_bounceAnimation.value * 0.1),
          child: FloatingActionButton.extended(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            elevation: 8,
            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_isExpanded ? "Collapse" : "Expand"),
          ),
        );
      },
    );
  }

  Widget _buildResultDetails() {
    if (widget.result == null) return const SizedBox.shrink();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with photo and verification status
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade100,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildPhoto(),
                  SizedBox(width: 24),
                  Expanded(
                    child: _buildVerificationStatus(),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30),
            
            // Personal Information Section
            _buildSectionHeader("Personal Information", Icons.person, color: Colors.blue),
            _buildResultCard("Full Name", "${widget.result!['dg1']["firstName"]} ${widget.result!['dg1']["lastName"]} \n${widget.result!["dg11"]['arabicName']}", color: Colors.blue),
            _buildResultCard("Given names", "${widget.result!['dg1']["firstName"]}, ${widget.result!['dg11']["nameOfHolder"]}", color: Colors.blue),
            _buildResultCard("Name", "${widget.result!['dg1']["lastName"]}", color: Colors.blue),
            _buildResultCard("Gender", widget.result!['dg1']["gender"], color: Colors.blue),
            _buildResultCard("Other Information", widget.result!["dg11"]['otherInfo'], color: Colors.blue),
            _buildResultCard("Nationality", widget.result!['dg1']["nationality"], color: Colors.blue),
            _buildResultCard("Date of Birth", widget.result!["dg11"]["fullDateOfBirth"], color: Colors.blue),
            _buildResultCard("Place of Birth", widget.result!["dg11"]["placeOfBirth"], color: Colors.blue),
            if (widget.result!["dg11"]["custodian"] == null || widget.result!["dg11"]["custodian"] == "")
              _buildResultCard("Custodian", widget.result!["dg11"]["custodyInformation"], color: Colors.blue)
            else
              _buildResultCard("Custodian", widget.result!["dg11"]["custodian"], color: Colors.blue),
            _buildResultCard("National Identification Number", widget.result!["dg11"]["personalNumber"], color: Colors.blue),
            
            SizedBox(height: 30),
            
            // Document Information Section
            _buildSectionHeader("Document Information", Icons.description, color: Colors.green),
            _buildResultCard("Document Code", widget.result!['dg1']["documentCode"], color: Colors.green),
            _buildResultCard("Document Number", widget.result!['dg1']["documentNumber"], color: Colors.green),
            _buildResultCard("Issuing Country", widget.result!['dg1']["issuingState"], color: Colors.green),
            
            SizedBox(height: 30),
            
            // Chip Information Section
            _buildSectionHeader("Chip Information", Icons.memory, color: Colors.purple),
            _buildResultCard("LDS Version", widget.result!['com']["ldsVersion"], color: Colors.purple),
            _buildResultCard("Unicode Version", widget.result!['com']["unicodeVersion"], color: Colors.purple),
            _buildResultCard("Data groups", widget.result!['com']["tagsList"].toString(), color: Colors.purple),
            
            SizedBox(height: 30),
            
            // Document Signing Certificate Section
            _buildSectionHeader("Document Signing Certificate", Icons.security, color: Colors.orange),
            _buildResultCard("Serial Number", widget.result!["sod"]['serialNumber'], color: Colors.orange),
            _buildResultCard("Signature algorithm", widget.result!["sod"]['Signature algorithm'], color: Colors.orange),
            _buildResultCard("Public Key Algorithm", widget.result!["sod"]['Public Key'].split(" ")[0], color: Colors.orange),
            _buildResultCard("Issuer", widget.result!["sod"]['issuer'], color: Colors.orange),
            _buildResultCard("Subject", widget.result!["sod"]['Subject'], color: Colors.orange),
            _buildResultCard("Valid from", widget.result!["sod"]['Valid from'], color: Colors.orange),
            _buildResultCard("Valid to", widget.result!["sod"]['Valid until'], color: Colors.orange),
            _buildResultCard("Signature", base64Encode(widget.result!["sod"]['signature']), color: Colors.orange),
            _buildResultCard("Version", widget.result!["sod"]['version'], color: Colors.orange),
            
            SizedBox(height: 30),
            
            // Country Signing Certificate Section
            _buildSectionHeader("Country Signing Certificate", Icons.verified, color: Colors.teal),
            _buildResultCard("Serial Number", widget.result!["sod"]['serialNumber'], color: Colors.teal),
            _buildResultCard("Signature algorithm", widget.result!["sod"]['Signature algorithm'], color: Colors.teal),
            _buildResultCard("Public Key Algorithm", widget.result!["sod"]['Public Key'].split(" ")[0], color: Colors.teal),
            _buildResultCard("Issuer", widget.result!["sod"]['issuer'], color: Colors.teal),
            _buildResultCard("Subject", widget.result!["sod"]['Subject'], color: Colors.teal),
            _buildResultCard("Valid from", widget.result!["sod"]['Valid from'], color: Colors.teal),
            _buildResultCard("Valid to", widget.result!["sod"]['Valid until'], color: Colors.teal),
            _buildResultCard("Signature", base64Encode(widget.result!["sod"]['signature']), color: Colors.teal),
            _buildResultCard("Version", widget.result!["sod"]['version'], color: Colors.teal),
            
            SizedBox(height: 30),
            
            // Signature Section
            _buildSectionHeader("Signature", Icons.draw, color: Colors.red),
            Container(
              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade200,
                    Colors.red.shade100,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.shade400,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(
                  Uint8List.fromList(base64Decode(widget.result!['dg7']["images"][0])),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // MRZ Section
            _buildSectionHeader("MRZ from chip", Icons.qr_code, color: Colors.indigo),
            _buildResultCard("", widget.result!['dg1']["fullMrz"], color: Colors.indigo),
            
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Document Information",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade600,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: _buildResultDetails(),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

