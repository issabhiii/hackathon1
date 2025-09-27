import 'package:flutter/material.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';

class SharedNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isDarkMode;
  final void Function(int)? onItemTapped;

  const SharedNavBar({
    super.key,
    required this.currentIndex,
    required this.isDarkMode,
    this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 30.0;
    final Color primaryColor = const Color.fromARGB(
      255,
      50,
      183,
      255,
    ); // Accuray blue
    final Color bgColor = primaryColor;
    final Color indicatorColor = Colors.white;
    final Color selectedIconColor = Colors.black;
    final Color unselectedIconColor = Colors.white.withOpacity(0.75);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            width: 420, // wide enough for 4 items
            height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: AnimatedToggleSwitch<int>.rolling(
                current: currentIndex,
                values: const [
                  0,
                  1,
                  2,
                  3,
                ], // 0:Home, 1:Upload, 2:Records, 3:Settings
                spacing: 16.0,
                indicatorSize: const Size.square(48),
                onChanged: (index) => onItemTapped?.call(index),
                iconBuilder: (value, selected) {
                  final Color iconColor = selected
                      ? selectedIconColor
                      : unselectedIconColor;

                  switch (value) {
                    case 0:
                      // Home (Accuray logo)
                      return Center(
                        child: Image.asset(
                          'assets/accuray.png',
                          height: 28,
                          // If tinting the logo looks odd, comment the next line:
                          color: iconColor,
                        ),
                      );
                    case 1:
                      // Upload
                      return Icon(
                        Icons.upload_file,
                        size: iconSize,
                        color: iconColor,
                      );
                    case 2:
                      // Records
                      return Icon(
                        Icons.folder,
                        size: iconSize,
                        color: iconColor,
                      );
                    case 3:
                      // Settings
                      return Icon(
                        Icons.settings,
                        size: iconSize,
                        color: iconColor,
                      );
                    default:
                      return Icon(
                        Icons.circle,
                        size: iconSize,
                        color: iconColor,
                      );
                  }
                },
                style: ToggleStyle(
                  backgroundColor: bgColor,
                  borderRadius: BorderRadius.circular(32),
                  indicatorColor: indicatorColor,
                  indicatorBorderRadius: BorderRadius.circular(32),
                  borderColor: Colors.transparent,
                  boxShadow: [], // flat look
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
