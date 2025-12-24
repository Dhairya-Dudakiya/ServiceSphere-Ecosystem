import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servicesphereagent/features/auth/screens/agent_login_screen.dart';
import 'package:servicesphereagent/features/auth/screens/pending_approval_screen.dart';
import 'package:servicesphereagent/features/dashboard/agent_dashboard_screen.dart';

class AgentAuthGate extends StatelessWidget {
  const AgentAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Listen to Authentication State
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If NO user is logged in, show Login Screen
        if (!snapshot.hasData) {
          return const AgentLoginScreen();
        }

        // If user IS logged in, we must check their 'agents' document
        // to see if they are verified.
        final User user = snapshot.data!;

        return StreamBuilder<DocumentSnapshot>(
          // 2. Listen to the Agent's Firestore Document
          stream: FirebaseFirestore.instance
              .collection('agents')
              .doc(user.uid)
              .snapshots(),
          builder: (context, agentSnapshot) {
            if (agentSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If the document doesn't exist or has an error
            if (!agentSnapshot.hasData || !agentSnapshot.data!.exists) {
              return const AgentLoginScreen(); // Fallback
            }

            final agentData =
                agentSnapshot.data!.data() as Map<String, dynamic>;
            final bool isVerified = agentData['isVerified'] ?? false;

            // 3. Logic: Verified vs. Pending
            if (isVerified) {
              // Agent is approved! Show the Dashboard.
              return const AgentDashboardScreen();
            } else {
              // Agent is NOT approved. Show Pending screen.
              return const PendingApprovalScreen();
            }
          },
        );
      },
    );
  }
}
