import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late Razorpay _razorpay;

  // Tracks which amount was selected — needed in success callback
  double _pendingAmount = 0;

  // ─── RAZORPAY KEY ───────────────────────────────────────────────────────────
  // Switch to rzp_live_ key when going to production
  static const String _razorpayKey = 'rzp_test_SgeGtd2j5DHeOf';

  // ─── LIFECYCLE ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ─── RAZORPAY HANDLERS ─────────────────────────────────────────────────────

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (_user == null) return;

    try {
      // Run as a batch — either both succeed or both fail
      final batch = FirebaseFirestore.instance.batch();

      // 1. Credit wallet balance
      final agentRef = FirebaseFirestore.instance
          .collection('agents')
          .doc(_user!.uid);
      batch.update(agentRef, {
        'walletBalance': FieldValue.increment(_pendingAmount),
      });

      // 2. Log transaction with Razorpay payment ID for audit
      final txRef = FirebaseFirestore.instance
          .collection('walletTransactions')
          .doc();
      batch.set(txRef, {
        'agentId': _user!.uid,
        'amount': _pendingAmount,
        'type': 'credit',
        'description': 'Wallet Recharge via Razorpay',
        'razorpayPaymentId': response.paymentId ?? '',
        'razorpayOrderId': response.orderId ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'success',
      });

      await batch.commit();

      if (mounted) {
        _showSuccessSheet(_pendingAmount, response.paymentId ?? '');
      }
    } catch (e) {
      debugPrint('Error crediting wallet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment received but wallet update failed. Contact support. '
              'Payment ID: ${response.paymentId}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }

    _pendingAmount = 0;
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _pendingAmount = 0;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message ?? 'Payment failed. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _pendingAmount = 0;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing via ${response.walletName}...')),
      );
    }
  }

  // ─── OPEN RAZORPAY CHECKOUT ─────────────────────────────────────────────────

  void _startPayment(double amount) {
    if (_user == null) return;

    _pendingAmount = amount;

    final options = {
      'key': _razorpayKey,
      'amount': (amount * 100).toInt(), // Razorpay uses paise
      'name': 'ServiceSphere',
      'description': 'Wallet Recharge ₹${amount.toInt()}',
      'prefill': {
        'email': _user!.email ?? '',
        'contact': _user!.phoneNumber ?? '',
      },
      'theme': {
        'color': '#2E7D32', // Your app green
      },
      'modal': {'confirm_close': true, 'animation': true},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open payment screen. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── CUSTOM AMOUNT DIALOG ───────────────────────────────────────────────────

  void _showCustomAmountDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Enter Amount',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: 'Enter amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter an amount';
              final amount = double.tryParse(v);
              if (amount == null) return 'Invalid amount';
              if (amount < 10) return 'Minimum recharge is ₹10';
              if (amount > 50000) return 'Maximum recharge is ₹50,000';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(controller.text);
                Navigator.pop(ctx);
                _startPayment(amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  // ─── SUCCESS BOTTOM SHEET ───────────────────────────────────────────────────

  void _showSuccessSheet(double amount, String paymentId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(0)} added to your wallet',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Payment ID: $paymentId',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── WITHDRAW DIALOG ────────────────────────────────────────────────────────

  void _showWithdrawDialog(double currentBalance) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Withdraw Earnings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Available: ₹${currentBalance.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount to withdraw',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  final amount = double.tryParse(v);
                  if (amount == null) return 'Invalid amount';
                  if (amount < 100) return 'Minimum withdrawal is ₹100';
                  if (amount > currentBalance) {
                    return 'Insufficient balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Withdrawals are processed within 24 hours to your registered bank account.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final amount = double.parse(controller.text);
                      Navigator.pop(ctx);
                      await _processWithdrawal(amount);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Request Withdrawal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PROCESS WITHDRAWAL ─────────────────────────────────────────────────────

  Future<void> _processWithdrawal(double amount) async {
    if (_user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Deduct from wallet
      final agentRef = FirebaseFirestore.instance
          .collection('agents')
          .doc(_user!.uid);
      batch.update(agentRef, {'walletBalance': FieldValue.increment(-amount)});

      // Log withdrawal request
      final txRef = FirebaseFirestore.instance
          .collection('walletTransactions')
          .doc();
      batch.set(txRef, {
        'agentId': _user!.uid,
        'amount': amount,
        'type': 'debit',
        'description': 'Withdrawal Request',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Create withdrawal request for admin to process
      final withdrawRef = FirebaseFirestore.instance
          .collection('withdrawalRequests')
          .doc();
      batch.set(withdrawRef, {
        'agentId': _user!.uid,
        'agentName': _user!.displayName ?? 'Agent',
        'amount': amount,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '₹${amount.toStringAsFixed(0)} withdrawal requested. '
              'Processing within 24 hours.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_user == null) {
      return const Scaffold(body: Center(child: Text('Login Required')));
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // ── BALANCE CARD ───────────────────────────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('agents')
                .doc(_user!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.hasData && snapshot.data!.exists
                  ? snapshot.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

              final double balance = (data['walletBalance'] ?? 0.0).toDouble();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Balance
                    const Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹ ${NumberFormat('#,##0.00').format(balance)}',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Add Money + Withdraw buttons
                    Row(
                      children: [
                        Expanded(
                          child: _WalletActionButton(
                            icon: Icons.add_rounded,
                            label: 'Add Money',
                            onTap: () => _showRechargeSheet(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WalletActionButton(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Withdraw',
                            onTap: balance >= 100
                                ? () => _showWithdrawDialog(balance)
                                : null,
                            disabled: balance < 100,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // ── TRANSACTION HISTORY ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Transaction History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('walletTransactions')
                  .where('agentId', isEqualTo: _user!.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Index required in Firebase Console.\nCheck debug logs for the link.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[300]),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 52,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add money to get started',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _TransactionTile(data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── RECHARGE BOTTOM SHEET ──────────────────────────────────────────────────

  void _showRechargeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Money',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select an amount or enter custom',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Quick amounts grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [50, 100, 200, 500, 1000, 2000]
                  .map(
                    (amount) => _QuickAmountButton(
                      amount: amount.toDouble(),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startPayment(amount.toDouble());
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Custom amount
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCustomAmountDialog();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Enter Custom Amount'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET ACTION BUTTON (Add Money / Withdraw)
// ═══════════════════════════════════════════════════════════════════════════════

class _WalletActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;

  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled
          ? Colors.white.withOpacity(0.1)
          : Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: disabled ? Colors.white38 : Colors.white,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK AMOUNT BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickAmountButton extends StatelessWidget {
  final double amount;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : theme.colorScheme.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Text(
            '₹ ${amount.toInt()}',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSACTION TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TransactionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCredit = data['type'] == 'credit';
    final double amount = (data['amount'] ?? 0).toDouble();
    final String desc = data['description'] ?? 'Transaction';
    final String status = data['status'] ?? 'success';
    final Timestamp? ts = data['timestamp'];
    final String date = ts != null
        ? DateFormat('MMM d, h:mm a').format(ts.toDate())
        : 'Just now';

    // Status color for pending withdrawals
    Color statusColor = isCredit ? Colors.green : Colors.red;
    if (status == 'pending') statusColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == 'pending'
                  ? Icons.schedule_rounded
                  : isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),

          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      date,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '${isCredit ? '+' : '-'} ₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
