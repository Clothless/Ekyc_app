# eKYC App

A modern Flutter application for electronic Know Your Customer (KYC) verification with document scanning, OCR text extraction, and identity verification capabilities.

## 🚀 Features

- **Document Scanning**: Scan ID cards, passports, and driver's licenses
- **OCR Text Extraction**: Extract text from document images
- **Face Recognition**: Verify identity through facial recognition
- **Beautiful UI/UX**: Modern animations and intuitive design
- **Multi-platform**: Support for Android, iOS, and Web

## 📱 Screenshots

### Onboarding Flow
- Welcome screen with security verification
- Document scanning tutorial
- Identity verification completion

### Main Features
- Document type selection (ID Card, Passport, OCR)
- Camera integration for document capture
- Real-time text extraction
- Enhanced user interface with animations

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.5.3
- **Backend**: Node.js with Python integration
- **OCR**: Google ML Kit, Tesseract
- **Face Recognition**: Custom Python implementation
- **Animations**: Flutter built-in animation system
- **State Management**: Flutter StatefulWidget

## 📋 Prerequisites

- Flutter SDK (3.5.3 or higher)
- Dart SDK
- Android Studio / VS Code
- Git
- Node.js (for backend)
- Python 3.8+ (for face recognition)

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Ekyc_app
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Setup backend (optional)**
   ```bash
   cd backend
   npm install
   pip install -r requirements.txt
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
Ekyc_app/
├── lib/
│   ├── main.dart                 # Main application entry
│   └── pages/                    # Application screens
│       ├── Idcard.dart           # ID card scanning
│       ├── Passport.dart         # Passport scanning
│       ├── DriverLicense.dart    # Driver license scanning
│       ├── edit_ocr_result_screen.dart
│       └── result_page.dart
├── assets/
│   ├── images/                   # Static images
│   ├── lottie/                   # Animation files
│   ├── fonts/                    # Custom fonts
│   └── tessdata/                 # OCR training data
├── backend/                      # Backend server
│   ├── server.js                 # Node.js server
│   ├── comparefaces.py           # Face recognition
│   └── uploads/                  # Uploaded files
├── android/                      # Android configuration
├── ios/                          # iOS configuration
└── web/                          # Web configuration
```

## 🎨 UI/UX Enhancements

### Animations
- **Pulsing Icons**: Subtle scale animations for interactive elements
- **Sliding Transitions**: Smooth page transitions with slide effects
- **Rotating Loaders**: Custom loading animations
- **Fade Effects**: Smooth opacity transitions

### Visual Design
- **Gradient Backgrounds**: Multi-layered gradients for depth
- **Card-based Layout**: Modern card design for content organization
- **Color-coded Features**: Each feature has its own theme color
- **Enhanced Typography**: Better font weights and spacing

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the root directory:
```env
API_BASE_URL=http://your-backend-url:8000
OCR_ENDPOINT=/extract-text-algerian-id
FACE_RECOGNITION_ENDPOINT=/compare-faces
```

### Backend Configuration
Update `backend/server.js` with your server settings:
```javascript
const PORT = process.env.PORT || 8000;
const UPLOAD_DIR = './uploads';
```

## 📱 Usage

1. **Launch the app** and go through the onboarding flow
2. **Choose verification method**:
   - Scan ID Card
   - Scan Passport
   - OCR Only
3. **Capture document** using camera or select from gallery
4. **Review extracted data** and edit if necessary
5. **Complete verification** process

## 🔒 Security Features

- **Secure File Upload**: Files are processed securely
- **Data Encryption**: Sensitive data is encrypted
- **API Key Protection**: API keys are stored securely
- **Face Recognition**: Biometric verification

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

## 📦 Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues:

1. Check the [Issues](https://github.com/your-repo/issues) page
2. Create a new issue with detailed description
3. Include device information and error logs

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Google ML Kit for OCR capabilities
- Tesseract for text recognition
- OpenCV for image processing

## 📈 Roadmap

- [ ] Multi-language support
- [ ] Offline mode
- [ ] Advanced face recognition
- [ ] Blockchain integration
- [ ] Real-time collaboration
- [ ] Advanced analytics dashboard

---

**Made with ❤️ using Flutter**
