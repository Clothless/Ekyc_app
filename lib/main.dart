// 🎨 Version améliorée avec fond et transition comme l'écran ID Card
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'pages/Idcard.dart';
import 'pages/DriverLicense.dart';
import 'pages/Passport.dart';
import 'package:lottie/lottie.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eKYC Form',
      debugShowCheckedModeBanner: false,
      home: OnboardingPage1(),
            initialRoute: '/',
      routes: {
        '/idcard': (context) => const Idcard(documentType: "ID Card"),
        '/driverlicense': (context) => const Driverlicense(documentType: "Driving License"),
        '/passport': (context) => const Passport(documentType: "Passport"),
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


class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String? selectedOption;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void navigateToNextPage() {
    if (selectedOption == "ID Card") {
      Navigator.pushNamed(context, '/idcard');
    } else if (selectedOption == "Driving License") {
      Navigator.pushNamed(context, '/driverlicense');
    } else if (selectedOption == "Passport") {
      Navigator.pushNamed(context, '/passport');
    }
  }

  Widget documentCard(String label, IconData icon) {
    final isSelected = selectedOption == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOption = label;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isSelected ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.white30, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        transform: isSelected
            ? (Matrix4.identity()..scale(1.03))
            : Matrix4.identity(),
        child: Row(
          children: [
            Icon(icon, size: 26, color: Colors.white),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF155970), Color(0xFF2A0A3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 160),
                    const SizedBox(height: 20),
                    const Text(
                      'Choose your document',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    documentCard("ID Card", Icons.credit_card),
                    documentCard("Driving License", Icons.directions_car),
                    documentCard("Passport", Icons.travel_explore),
                    const Spacer(),
                    GestureDetector(
                      onTap: selectedOption != null ? navigateToNextPage : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: selectedOption != null
                              ? const LinearGradient(
                                  colors: [Color(0xFF7A4FF3), Color(0xFF12002C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [Colors.grey.shade400, Colors.grey.shade300],
                                ),
                          boxShadow: selectedOption != null
                              ? [
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: const Center(
                          child: Text(
                            "Continue",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
