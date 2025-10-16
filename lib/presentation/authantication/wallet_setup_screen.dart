import 'package:cryptowallet/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:cryptowallet/theme/app_theme.dart';

class WalletSetupScreen extends StatelessWidget {
  static const String routeName = '/wallet-setup';
  static const Color _pageBg = Color(0xFF0B0D1A); // deep navy
  const WalletSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                const Text(
                  'Welcome to Zyara',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textHighEmphasis,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Securely manage your digital assets',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textMediumEmphasis,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Access Wallet Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.loginScreen);
                    },
                    child: const Text('Access Existing Wallet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Create New Wallet Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      _showTermsDialog(context);
                    },
                    child: const Text('Create New Wallet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show Terms and Conditions dialog with sticky checkbox + button
  void _showTermsDialog(BuildContext context) {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E2235),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Terms of Use",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white24, height: 1),

                    // Scrollable Terms Text
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: const Text(
                          '''Terms of Use
1. Introduction
These Terms and Conditions (“Terms”) govern your access to and use of the Zayra platform (“Zayra,” “we,” “us,” or “our”), operated by Zayra Technologies Inc., a Delaware corporation with its principal office located at [Insert Address], New York, USA.
By registering for an account or using the Zayra platform (the “Platform”), you agree to be bound by these Terms, our Privacy Policy, and any additional terms that may apply to specific services or features.
If you do not agree, you must not access or use the Platform.
2. Nature of the Platform
Zayra provides users with a secure, technology-based environment to maintain balances, perform transactions, and access digital services made available within the Zayra ecosystem.
The Platform facilitates digital value transfers exclusively between approved users and services available within the Zayra environment. The Platform functions as a custodial wallet service. All transfers initiated through Zayra’s custodial wallet platform are first recorded within Zayra’s internal systems. Transactions may be subject to technical verification, compliance screening (including AML and sanctions checks), and reconciliation procedures before being broadcast to the blockchain network.
Balances reflected in your account are maintained by Zayra and are intended for use within the Platform. External transfers, withdrawals, or redemptions may not be supported, and their availability depends on technical, legal, and regulatory considerations.
3. Eligibility
You may use the Platform only if you:
Are at least 18 years old, or have parental consent if under the age of majority in your jurisdiction.
Are capable of entering a legally binding agreement.
Have provided accurate and complete registration details.
Have not been previously suspended or removed from the Platform.
If you represent an entity, you confirm that you have the authority to bind that entity to these Terms.
4. Account Creation and Security
4.1 Account Registration 
To access certain features, you may be required to register an account. During registration, you must provide accurate information and maintain its accuracy throughout your use of the Platform.
4.2 Account Responsibility
You are responsible for maintaining the confidentiality of your login credentials and for all activities conducted under your account. Notify us immediately at [support@Zayra] if you suspect unauthorized access.
4.3 Security Measures 
Zayra employs reasonable administrative, technical, and physical safeguards to protect your account information and transaction data. However, we cannot guarantee absolute protection against unauthorized access, cyber threats, or data breaches.
5. Platform Balances
5.1 Balances and Records
Your account may display a balance representing the value available for use within Zayra’s ecosystem. These balances are recorded and maintained by Zayra, and the authoritative record of your balance resides within Zayra’s system.
5.2 Purpose and Use
Balances may be used to perform permitted transactions within Zayra, including sending or receiving value between users, accessing partner services, or participating in approved activities within the Platform.
5.3 Non-Transferability and Use Limitations
Balances are not instruments of currency and may not be exchanged, withdrawn, or transferred outside of Zayra, except where explicitly enabled by Zayra under applicable law.
5.4 Adjustments and Corrections
Zayra may, at its discretion, adjust or correct balances in the event of technical errors, duplicate entries, system malfunctions, or reconciliation discrepancies. Zayra’s records shall be final and binding in determining balance status.
6. Transactions
6.1 Initiation and Authorization
Transactions initiated through your account are processed based on your instructions. You are solely responsible for ensuring accuracy before confirming any transaction.
6.2 Completion and Finality
Once a transaction is confirmed, it is generally irreversible, except where reversal is required to correct an operational or compliance-related error.
6.3 Processing and Delays
Transactions may be delayed, held, or cancelled where Zayra determines that additional verification is required, where system conditions prevent timely processing, or where Zayra reasonably believes the transaction is unauthorized or unlawful.
6.4 Platform Discretion
Zayra retains full discretion to determine the methods, timing, and conditions under which transactions are processed, completed, or withheld.
7. Fees and Charges
Zayra may charge service or transaction fees in connection with the use of certain features. All applicable fees will be disclosed before the completion of a transaction.
You are responsible for any taxes applicable to your use of the Platform, and you acknowledge that Zayra may deduct applicable charges as required by law.
8. Prohibited Use
You agree not to use the Platform to:
Violate any law, regulation, or order issued by a governmental authority.
Engage in fraudulent, deceptive, or unlawful conduct.
Infringe upon any third party’s intellectual property, privacy, or proprietary rights.
Disrupt or interfere with the integrity or security of the Platform or its systems.
Create multiple or misleading accounts.
Use the Platform for money laundering, terrorist financing, or any illegal purpose.


Zayra reserves the right to investigate, suspend, or terminate accounts suspected of prohibited activity.
9. Platform Operations
Zayra manages and administers all underlying systems related to user balances and transactions. We may engage service providers for hosting, security, analytics, or data storage.
Operational integrity may require periodic reconciliation, temporary restrictions, or system updates. You acknowledge that the availability of certain services may vary depending on technical or regulatory requirements.
10. Intellectual Property Rights
Zayra and its licensors retain all intellectual property rights related to the Platform, software, content, and branding.
You are granted a limited, revocable, non-exclusive, and non-transferable license to access and use the Platform in accordance with these Terms.
You may not:
Copy, distribute, or modify any part of the Platform.


Reverse-engineer or decompile software components.


Use Zayra’s trademarks without written authorization.


11. Communication and Notifications
By using Zayra, you consent to receive electronic communications related to your account, including notices, updates, and transactional confirmations.
Official communications may be sent to your registered email or displayed within the Platform.
You may contact us at:
 support@Zayra.example
 Zayra Technologies Private Limited, [Insert Address]
12. Disclaimers
The Platform and all related services are provided “as is” and “as available” without warranties of any kind.
To the maximum extent permitted by law, Zayra disclaims all express or implied warranties, including but not limited to:
Merchantability or fitness for a particular purpose.


Uninterrupted or error-free operation.


Accuracy, reliability, or completeness of information.


Zayra does not guarantee the continuous availability of the Platform or that transactions will always be processed without interruption.
13. Limitation of Liability
To the extent permitted by law:
Zayra shall not be liable for indirect, incidental, special, or consequential damages, including loss of profits, revenue, or goodwill.


Zayra’s total cumulative liability under these Terms shall not exceed INR 100,000 or the total amount of service fees paid by you to Zayra during the preceding twelve (12) months, whichever is higher.


Nothing in these Terms shall limit liability that cannot be lawfully excluded.
14. Indemnity
You agree to indemnify and hold harmless Zayra, its affiliates, officers, employees, and representatives from any claims, damages, liabilities, or expenses arising out of:
Your use or misuse of the Platform;


Your breach of these Terms; or


Any violation of law or third-party rights.


15. Termination and Suspension
Zayra may, at its discretion, suspend or terminate your account and restrict access where:
You violate these Terms or applicable law.


There is evidence of suspicious, fraudulent, or unauthorized activity.


Continued use may cause harm to the Platform, its users, or regulatory standing.


Upon termination, your right to use the Platform ceases immediately. Zayra may retain transaction data and account information as required under applicable law.
16. Governing Law
These Terms shall be governed by and construed in accordance with the laws of the State of New York, without regard to conflict-of-law principles.
17. Dispute Resolution and Arbitration
Any dispute, claim, or controversy arising out of or relating to these Terms or your use of the Platform will be resolved through binding arbitration administered by the American Arbitration Association (AAA) under its Commercial Arbitration Rules and the Federal Arbitration Act (FAA).
Seat and Venue: New York, New York, USA


Language: English


Arbitrator: One arbitrator, appointed under AAA rules


You and Zayra agree that all disputes will be resolved on an individual basis and not as part of a class or representative action.
18. Force Majeure
Zayra shall not be liable for any delay or failure to perform due to events beyond its reasonable control, including but not limited to natural disasters, network outages, acts of government, strikes, or system failures.
19. Amendments
Zayra may amend these Terms periodically. Updated Terms will be posted on the Platform with a revised effective date. Continued use after publication constitutes acceptance of the revised Terms.
20. Severability and Waiver
If any provision of these Terms is deemed invalid or unenforceable, the remaining provisions will remain in effect. Failure by Zayra to enforce any provision shall not be construed as a waiver of its rights.
21. Entire Agreement
These Terms, together with the Privacy Policy, form the entire agreement between you and Zayra regarding your use of the Platform and supersede any prior understandings or agreements.
''',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14, height: 1.4),
                        ),
                      ),
                    ),

                    const Divider(color: Colors.white24, height: 1),

                    // Sticky Checkbox + Buttons
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                onChanged: (val) {
                                  setState(() {
                                    isChecked = val ?? false;
                                  });
                                },
                                activeColor: Colors.tealAccent[700],
                                checkColor: Colors.black,
                              ),
                              const Expanded(
                                child: Text(
                                  "I agree to the Terms and Conditions",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side:
                                        const BorderSide(color: Colors.white30),
                                    foregroundColor: Colors.white60,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: const Text("Cancel"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isChecked
                                      ? () {
                                          Navigator.pop(context);
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.createWalletScreen,
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isChecked
                                        ? Colors.tealAccent[700]
                                        : Colors.grey[700],
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  child: const Text("I Agree"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
