// 🎨 Version améliorée avec fond et transition comme l'écran ID Card
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'pages/Idcard.dart';
import 'pages/DriverLicense.dart';
import 'pages/Passport.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/idcard': (context) => const Idcard(documentType: "ID Card"),
        '/driverlicense': (context) => const Driverlicense(documentType: "Driving License"),
        '/passport': (context) => const Passport(documentType: "Passport"),
        '/nfc_biometric': (context) => const Idcard(documentType: "Biometric ID Card (NFC)"),
        '/nfc_passport': (context) => const Passport(documentType: "Passport (NFC)"),
      },
    );
  }
}

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildOnboardingStep(
      context,
      title: "Let’s start with verifying your identity",
      subtitle: "Choose the document you want and make sure it is clear and readable.",
      highlight: "Supported: ID | Driving License | Passport",
      animationAsset: 'assets/lottie/identity.json',
      buttonText: 'Next',
      progress: 0.33,
      onNext: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage2()),
      ),
    );
  }
}

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildOnboardingStep(
      context,
      title: "Upload Your Document",
      subtitle: "We need to scan the front and back side of your card.",
      highlight: "Avoid blur or reflections.",
      animationAsset: 'assets/lottie/idscan.json',
      buttonText: 'Next',
      progress: 0.66,
      onNext: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage3()),
      ),
    );
  }
}

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildOnboardingStep(
      context,
      title: "Take a selfie",
      subtitle: "Keep your face in the frame and look straight ahead.",
      highlight: "Make sure lighting is good and your eyes are open.",
      animationAsset: 'assets/lottie/selfie.json',
      buttonText: 'Finish',
      progress: 1.0,
      onNext: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreenAfterOnboarding()),
      ),
    );
  }
}

Widget _buildOnboardingStep(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String highlight,
  required String animationAsset,
  required String buttonText,
  required double progress,
  required VoidCallback onNext,
}) {
  return Scaffold(
    body: Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation( Color(0xFF155970)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 20),
                    Lottie.asset(animationAsset, height: 220),
                    Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (highlight.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              highlight,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color:  Color(0xFF155970),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF155970),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: Colors.black45,
                        ),
                        child: Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    )
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



class SplashScreenAfterOnboarding extends StatefulWidget {
  const SplashScreenAfterOnboarding({super.key});

  @override
  State<SplashScreenAfterOnboarding> createState() => _SplashScreenAfterOnboardingState();
}

class _SplashScreenAfterOnboardingState extends State<SplashScreenAfterOnboarding> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Lottie.asset(
          'assets/lottie/welcome.json',
          width: 250,
        ),
      ),
    );
  }
}


class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void navigateToNextPage(BuildContext context, String selectedOption) {
    if (selectedOption == "ID Card") {
      Navigator.pushNamed(context, '/idcard');
    } else if (selectedOption == "Driving License") {
      Navigator.pushNamed(context, '/driverlicense');
    } else if (selectedOption == "Passport") {
      Navigator.pushNamed(context, '/passport');
    } else if (selectedOption == "Biometric ID Card") {
      Navigator.pushNamed(context, '/nfc_biometric');
    } else if (selectedOption == "Passport (NFC)") {
      Navigator.pushNamed(context, '/nfc_passport');
    }
  }

  Widget documentCard(BuildContext context, String title, IconData icon) {
    return GestureDetector(
      onTap: () => navigateToNextPage(context, title),
      child: Card(
        color: Colors.blueGrey.shade900,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('eKYC App'),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 40, right: 20, left: 20),
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: [
              documentCard(context, "ID Card", Icons.credit_card),
              // documentCard(context, "Driving License", Icons.directions_car),
              documentCard(context, "Passport", Icons.travel_explore),
              // ExpansionTile(
              //   title: const Text(
              //     "NFC Chip",
              //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              //   ),
              //   iconColor: Colors.white,
              //   collapsedIconColor: Colors.white,
              //   childrenPadding: const EdgeInsets.only(left: 16),
              //   children: [
              //     documentCard(context, "Biometric ID Card", Icons.shield_moon_rounded),
              //     documentCard(context, "Passport (NFC)", Icons.shield_moon_rounded),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}