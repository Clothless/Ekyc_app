import 'package:flutter/material.dart';
import 'dart:math' as math;

class EditOCRResultScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const EditOCRResultScreen({required this.data, Key? key}) : super(key: key);

  @override
  State<EditOCRResultScreen> createState() => _EditOCRResultScreenState();
}

class _EditOCRResultScreenState extends State<EditOCRResultScreen> 
    with TickerProviderStateMixin {
  final Map<String, TextEditingController> _controllers = {};
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  bool _isEditing = false;
  bool _showSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
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
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);

    widget.data.forEach((key, value) {
      if (key != 'rawText') {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildFieldCard(String label, TextEditingController controller, {Color? color}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? Colors.indigo).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit,
                  color: (color ?? Colors.indigo).withOpacity(0.6),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  _formatLabel(label),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: (color ?? Colors.indigo).withOpacity(0.7),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter ${_formatLabel(label).toLowerCase()}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: (color ?? Colors.indigo).withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: (color ?? Colors.indigo).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: (color ?? Colors.indigo).withOpacity(0.6),
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatLabel(String key) {
    // First, replace underscores with spaces
    String formatted = key.replaceAll('_', ' ');
    
    // Handle camelCase by adding spaces before capital letters
    formatted = formatted.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Capitalize the first letter of each word
    return formatted.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _rescan() {
    Navigator.pop(context);
  }

  void _saveData() {
    setState(() {
      _showSuccessMessage = true;
      _isEditing = false;
    });
    
    // Hide success message after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccessMessage = false;
        });
      }
    });
  }

  Widget _buildSuccessMessage() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.shade300,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Data Saved Successfully!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Your OCR data has been updated",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isEnabled = true,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? color : Colors.grey.shade400,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isEnabled ? 2 : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = _controllers.entries.map(
      (entry) => _buildFieldCard(entry.key, entry.value, color: Colors.indigo),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit OCR Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade600,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.indigo.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.text_fields,
                            color: Colors.indigo.shade600,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Extracted Fields",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Review and edit the extracted information",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Success Message
                    if (_showSuccessMessage) _buildSuccessMessage(),

                    // Fields
                    ...fields,

                    SizedBox(height: 20),

                    // Buttons Section
                    _buildButton(
                      onPressed: () {
                        _isEditing ? _saveData() : null;
                      },
                      icon: Icons.save,
                      label: "Save Changes",
                      color: Colors.green,
                      isEnabled: _isEditing,
                    ),

                    _buildButton(
                      onPressed: _rescan,
                      icon: Icons.camera_alt,
                      label: "Rescan Image",
                      color: Colors.red,
                      isEnabled: true,
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
