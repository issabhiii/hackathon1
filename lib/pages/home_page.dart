import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String userName;
  final int submittedCount;
  final int receivedCount;
  final VoidCallback? onUploadTap;
  final VoidCallback? onLoginTap;

  const HomePage({
    super.key,
    this.userName = "User",
    this.submittedCount = 0,
    this.receivedCount = 0,
    this.onUploadTap,
    this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color.fromARGB(255, 34, 196, 255);
    final bool isLoggedIn = userName.trim().isNotEmpty && userName != "User";

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🏢 Company Logo
            Image.asset(
              'assets/accuray.png',
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, size: 80, color: Colors.red),
            ),
            const SizedBox(height: 24),

            // 👋 Greeting
            Text(
              "Hey $userName 👋",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),

            // little signed-in chip (only when logged in)
            if (isLoggedIn) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 16,
                      color: primaryColor.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Signed in",
                      style: TextStyle(
                        color: primaryColor.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Subtitle
            Text(
              "Here’s what’s happening today:",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // 📊 Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: "Submitted",
                    value: submittedCount,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: "Received",
                    value: receivedCount,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 💻 CTA Button
            ElevatedButton.icon(
              onPressed: onUploadTap,
              icon: const Icon(Icons.upload_file),
              label: const Text(
                "Upload New Specification",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Login Button (only show if not logged in)
            if (!isLoggedIn)
              TextButton(
                onPressed: onLoginTap,
                child: const Text(
                  "Login / Sign Up",
                  style: TextStyle(
                    color: Color.fromARGB(255, 29, 225, 255),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "$value",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
