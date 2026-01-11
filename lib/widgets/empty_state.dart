import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../styles.dart';

class EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const EmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppStyles.mSurface,
        borderRadius: AppStyles.bRadiusLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppStyles.mBackground,
              borderRadius: AppStyles.bRadiusLarge,
            ),
            child: Icon(
              LucideIcons.layoutDashboard,
              size: 48,
              color: AppStyles.mPrimary,
            ),
          ),
          const SizedBox(height: 32),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppStyles.mBackground, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppStyles.mTextPrimary,
                        width: 2.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.plus,
                      size: 24,
                      color: AppStyles.mTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Add new Project',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.mTextPrimary,
                      letterSpacing: -0.5,
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
