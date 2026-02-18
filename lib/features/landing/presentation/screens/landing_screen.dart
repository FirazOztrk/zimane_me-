import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Ziman\u00EA Me',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkBrown,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: AppColors.darkBrown, width: 5),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Cat Mascot',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.darkBrown,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 72,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.vibrantRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: const BorderSide(
                        color: AppColors.darkBrown,
                        width: 4,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  child: const Text('Dest Peke'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
