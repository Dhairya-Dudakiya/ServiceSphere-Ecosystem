import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Payment Methods",
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textColor, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 4),
            child: Text("Select Payment Mode",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5)),
          ),
          _buildPaymentOption(
              context, "Razorpay / UPI", Icons.security_rounded, true,
              subtitle: "Secure gateway enabled", isDark: isDark),
          const SizedBox(height: 16),
          _buildPaymentOption(
              context, "Cash on Delivery", Icons.payments_rounded, false,
              isDark: isDark),
          const SizedBox(height: 16),
          _buildPaymentOption(
              context, "Credit / Debit Card", Icons.credit_card_rounded, false,
              isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(
      BuildContext context, String title, IconData icon, bool isConnected,
      {String? subtitle, required bool isDark}) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isConnected
                  ? (isDark ? Colors.green.shade800 : Colors.green.shade200)
                  : Colors.transparent,
              width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: isConnected
                  ? Colors.green.withOpacity(0.15)
                  : Theme.of(context).primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon,
              color: isConnected
                  ? (isDark ? Colors.green.shade400 : Colors.green.shade600)
                  : Theme.of(context).primaryColor,
              size: 24),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 16)),
        subtitle: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(subtitle,
                    style: TextStyle(
                        color: isDark
                            ? Colors.green.shade400
                            : Colors.green.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)))
            : null,
        trailing: isConnected
            ? Icon(Icons.check_circle_rounded,
                color: isDark ? Colors.green.shade400 : Colors.green, size: 24)
            : Icon(Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
        onTap: () {
          if (!isConnected)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Payment integration coming soon!")));
        },
      ),
    );
  }
}
