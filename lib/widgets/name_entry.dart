import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';

class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key});

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _controller = TextEditingController();

  void _handleSubmit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      context.read<DayCrafterProvider>().setUserName(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.mBackground,
      body: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: GridDotPainter(dotColor: AppStyles.mTextSecondary),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(48.0),
              decoration: BoxDecoration(
                color: AppStyles.mSurface.withValues(alpha: 0.9),
                borderRadius: AppStyles.bRadiusLarge,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 24,
                      color: AppStyles.mTextSecondary,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    'DayCrafter',
                    style: TextStyle(
                      fontSize: 48,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      color: AppStyles.mPrimary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    "What's your name?",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppStyles.mTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppStyles.mTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex',
                      hintStyle: TextStyle(color: AppStyles.mTextSecondary),
                      filled: true,
                      fillColor: AppStyles.mBackground.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: AppStyles.bRadiusMedium,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.mPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.bRadiusMedium,
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
