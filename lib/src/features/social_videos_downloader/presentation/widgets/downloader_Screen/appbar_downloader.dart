import 'package:flutter/material.dart';
import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_strings.dart';

class AppBarWithLogo extends StatelessWidget {
  final Widget? action;

  const AppBarWithLogo({super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Image.asset(
            AppAssets.logo,
            height: 50,
            width: 50,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.video_collection,
                size: 50,
                color: Colors.white,
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            AppStrings.appName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
