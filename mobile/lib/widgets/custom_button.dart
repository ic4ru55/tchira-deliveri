import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String        texte;
  final VoidCallback? onPressed;
  final bool          isLoading;
  final Color?        couleur;
  final IconData?     icone;

  const CustomButton({
    super.key,
    required this.texte,
    required this.onPressed,
    this.isLoading = false,
    this.couleur,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: couleur ?? const Color(0xFF0D7377),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                width:  24,
                height: 24,
                child:  CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    texte,
                    style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}