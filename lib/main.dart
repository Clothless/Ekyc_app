import 'package:flutter/material.dart';
import 'pages/Idcard.dart'; // Import your existing pages
import 'pages/DriverLicense.dart';
import 'pages/Passport.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekyc Form',
      home: WelcomePage(),
    );
  }
}



class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? selectedOption;

  void navigateToNextPage() {
    if (selectedOption == "ID Card") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Idcard()),
      );
    } else if (selectedOption == "Driver License") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Driverlicense()),
      );
    } else if (selectedOption == "Passport") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Passport()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome to Ekyc"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Select Your Document Type",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            RadioListTile(
              title: Text("ID Card"),
              value: "ID Card",
              groupValue: selectedOption,
              onChanged: (value) {
                setState(() {
                  selectedOption = value as String;
                });
              },
            ),
            RadioListTile(
              title: Text("Driver License"),
              value: "Driver License",
              groupValue: selectedOption,
              onChanged: (value) {
                setState(() {
                  selectedOption = value as String;
                });
              },
            ),
            RadioListTile(
              title: Text("Passport"),
              value: "Passport",
              groupValue: selectedOption,
              onChanged: (value) {
                setState(() {
                  selectedOption = value as String;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: selectedOption != null ? navigateToNextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text("Continue", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}




