// lib/presentation/tech_support_screen.dart
import 'package:cryptowallet/core/support_chat_badge.dart';
import 'package:cryptowallet/core/support_chat_push.dart';
import 'package:cryptowallet/presentation/profile_screen/chatsupport.dart';
import 'package:flutter/material.dart';

class TechSupportScreen extends StatefulWidget {
  const TechSupportScreen({super.key});

  @override
  State<TechSupportScreen> createState() => _TechSupportScreenState();
}

class _TechSupportScreenState extends State<TechSupportScreen> {
  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);

  @override
  void initState() {
    super.initState();
    // Start background socket listener for `new-admin-message`
    SupportChatPush.instance.init();
  }

  // Open the support chat; when returning, ensure badge is cleared
  void _openTicket() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupportChatScreen()),
    ).then((_) {
      // When user comes back from chat, unread should be zero.
      SupportChatBadge.instance.clear();
    });
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const _DocScreen(title: 'Privacy Policy')),
    );
  }

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Vault Wallet',
      applicationVersion: '1.0.0',
      applicationLegalese: '© ${DateTime.now().year} Vault, Inc.',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.account_balance_wallet, color: Colors.white),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
            'Secure custodial wallet. This app is provided as-is without warranty.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Tech & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionHeader('Support'),
          const SizedBox(height: 8),

          // “Open Ticket” card with live unread badge using SupportChatBadge
          AnimatedBuilder(
            animation: SupportChatBadge.instance,
            builder: (context, _) {
              final unread = SupportChatBadge.instance.unread;

              Widget? trailing;
              if (unread > 0) {
                trailing = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                );
              }

              return _SettingCard(
                leadingIcon: Icons.chat_bubble_outline,
                title: 'Open Ticket',
                subtitle: unread > 0
                    ? '${unread} new message${unread > 1 ? 's' : ''}'
                    : 'Report an issue',
                trailing: trailing,
                onTap: _openTicket,
              );
            },
          ),

          // const SizedBox(height: 12),

          // _SettingCard(
          //   leadingIcon: Icons.receipt_long_outlined,
          //   title: 'Terms of Use',
          //   subtitle: 'Access the terms of use',
          //   onTap: _openTerms,
          // ),
          const SizedBox(height: 12),

          _SettingCard(
            leadingIcon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Access the Privacy Policy',
            onTap: _openPrivacy,
          ),
          const SizedBox(height: 12),

          _SettingCard(
            leadingIcon: Icons.info_outline,
            title: 'About',
            subtitle: 'App information & licenses',
            onTap: _openAbout,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _TechSupportScreenState._faint,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TechSupportScreenState._card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(leadingIcon,
                  color: _TechSupportScreenState._faint, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        )),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                            color: _TechSupportScreenState._faint,
                            fontSize: 14,
                          )),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  const Icon(Icons.chevron_right,
                      color: _TechSupportScreenState._faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple in-app document screen used for Terms and Privacy.
class _DocScreen extends StatelessWidget {
  const _DocScreen({required this.title});
  final String title;

  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF171B2B);
  static const _faint = Color(0xFFBFC5DA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SingleChildScrollView(
          child: Text(
            '''Last updated: 2025-01-01

Privacy Policy
1. Introduction
Welcome to Zyara Technologies Private Limited (“Zyara,” “we,” “us,” or “our”).
Zyara respects your privacy and is committed to protecting your personal information. This Privacy Policy (“Policy”) describes how we collect, use, disclose, and safeguard information about you when you access or use our website, mobile applications, products, and other services (collectively, the “Platform”).
This Policy also explains the rights and choices you have with respect to your data and how you can exercise them.
By registering for an account, using our Platform, or otherwise providing information to us, you consent to the collection and use of your personal data as described in this Policy.
 If you do not agree with this Policy, please refrain from using the Platform.
2. Scope and Applicability
This Policy applies to:
All users of Zyara’s Platform, including individuals and entities that create accounts or interact with features on the Platform.
All personal data collected through our website, applications, communication channels, or integrations.
All processing activities performed by Zyara in India or in jurisdictions where we operate.
This Policy does not apply to third-party websites, applications, or services that are not controlled by Zyara, even if they are linked through the Platform. We encourage you to review the privacy policies of such third parties.
3. Information We Collect
Zyara collects information directly from you, automatically through your use of the Platform, and from third parties. The information we collect depends on how you use the Platform and the features you access.
3.1 Information You Provide to Us
We collect information that you voluntarily provide when you create or manage your account, use features, or communicate with us. This may include:
Account information: Your name, phone number, email address, password, profile photo, user ID, and other details provided during registration.


Identity verification data: KYC documents such as PAN, Aadhaar, government-issued ID, or other documentation when required by law or policy.


Transaction information: Details of transfers, exchanges, payments, or value movements performed within the Zyara ecosystem.


Communications: Information contained in emails, messages, feedback forms, or customer service inquiries.


Preferences: Choices you make regarding notifications, features, or settings.


Business information: For enterprise users, details about company registration, representatives, and related data.


3.2 Information We Collect Automatically
When you interact with the Platform, we automatically collect certain data to improve our services and maintain operational integrity. This may include:
Device information: Type of device, hardware model, operating system, unique device identifiers, and mobile network information.


Usage data: Logs of your activity on the Platform, such as date/time of access, IP address, features used, transaction activity, and duration of sessions.


Cookies and tracking data: Information collected via cookies, web beacons, and similar technologies to enhance user experience and security.


Network information: Browser type, language preferences, time zone, and connection details.


We may aggregate or anonymize this information for analytics and system improvement purposes.
3.3 Information from Third Parties
We may receive information from external sources, including:
Verification partners: For KYC, fraud prevention, or authentication services.


Analytics providers: That help us understand user behavior and service performance.


Business partners or affiliates: In relation to products, offers, or services within the Zyara ecosystem.


Publicly available databases: Where such collection is lawful.


4. How We Use Your Information
We process your data for legitimate business purposes and in accordance with applicable law.
We use the information we collect for the following purposes:
4.1 Service Provision
To register and maintain user accounts.


To provide access to Platform features and services.


To enable value transfers, payments, and other authorized transactions within the Zyara environment.


To maintain accurate records of balances and transactions.


4.2 Platform Operation and Improvement
To monitor system performance, usage trends, and functionality.


To develop new features, products, or enhancements.


To personalize user experience based on past interactions or preferences.


4.3 Compliance and Risk Management
To comply with legal, regulatory, or contractual obligations.


To conduct audits, monitor compliance, and maintain internal controls.


To prevent, detect, and investigate fraud, abuse, or unauthorized access.


To perform customer due diligence and identity verification where required.


4.4 Communication and Support
To send administrative or service-related notifications.


To respond to user queries, complaints, or feedback.


To deliver in-app or email updates about system changes or new services.


4.5 Marketing and Engagement
To send you product updates, promotional materials, or announcements (only where you have opted in).


To provide you with offers related to Zyara’s ecosystem partners.


4.6 Legal and Regulatory Obligations
To cooperate with law enforcement or regulatory authorities when required.


To maintain records for audits, dispute resolution, and compliance purposes.


We do not use your data for profiling or automated decision-making that has legal or significant effects on you without your explicit consent.
5. How We Share Information
Zyara does not sell, rent, or trade your personal data. However, we may share information with specific parties as necessary to provide and improve our services.
5.1 Service Providers
We may share information with third-party vendors that support Zyara in areas such as hosting, cloud infrastructure, customer service, identity verification, analytics, and communications.


All such vendors operate under strict data protection agreements and are obligated to safeguard your information.
5.2 Affiliates and Group Entities
We may share information with our subsidiaries, affiliates, or related entities to facilitate internal operations, cross-platform services, or user support.
5.3 Partners within the Zyara Ecosystem
We may disclose limited information to ecosystem partners for the purpose of facilitating authorized activities within the Platform, such as in-platform transactions, rewards, or collaborations.
5.4 Legal Disclosures
We may disclose your information if required by:
Applicable laws, regulations, or legal processes.


Government or law enforcement requests.


Regulatory or compliance requirements.


To protect the safety, rights, or property of Zyara, its users, or the public.


5.5 Business Transfers
If Zyara is involved in a merger, acquisition, restructuring, or sale of assets, your information may be transferred as part of that transaction, subject to confidentiality protections.
6. Data Retention
We retain personal information only as long as necessary for the purposes described in this Policy, including:
Compliance with legal obligations.


Maintenance of transaction and account records.


Audit and dispute resolution.


Security and fraud prevention.


Transactional records may be retained for longer durations to satisfy regulatory requirements. When personal data is no longer needed, we delete or anonymize it securely.
7. Data Security
Zyara implements industry-standard administrative, technical, and organizational measures to protect your data. These include:
Encrypted storage and transmission of sensitive information.


Role-based access controls and employee confidentiality agreements.


Continuous system monitoring and intrusion detection mechanisms.


Regular security audits and compliance reviews.


While we take all reasonable precautions, no electronic storage or transmission is completely secure. You acknowledge that you share information with us at your own discretion and that residual risks may remain.
8. Your Rights and Choices
Subject to applicable law, you may have the following rights regarding your personal data:
Right to access – to know what personal data we hold about you.


Right to correction – to update or correct inaccurate or incomplete information.


Right to erasure – to request deletion of your data, where legally permissible.


Right to withdraw consent – to revoke previously granted permissions.


Right to data portability – to obtain a copy of your personal data in a structured format, where applicable.


Right to grievance redressal – to raise complaints or concerns regarding data handling.
To exercise these rights, contact us at [privacy@Zyara…]
We will verify your identity before processing any request and respond within statutory timelines.
9. Cookies and Tracking Technologies
Zyara uses cookies and related technologies to operate efficiently and improve user experience.
Cookies are small files stored on your device that help:
Maintain login sessions.

Remember preferences and settings.

Analyze Platform usage and performance.

Support fraud detection and prevention.

You can control or delete cookies via browser settings. However, disabling cookies may limit your ability to use some features of the Platform.
10. Data Transfers
Although Zyara primarily stores and processes data in India, we may transfer limited data to trusted third-party processors located in other jurisdictions for specific operational purposes (such as analytics or cloud hosting).
Where data is transferred internationally, we ensure that adequate legal safeguards are implemented, including contractual protections and security standards equivalent to those required under Indian law.
11. Protection of Minors
Zyara does not knowingly collect personal data from individuals under the age of 18 without parental or guardian consent.
If we learn that we have inadvertently collected data from a minor without proper authorization, we will take steps to delete it immediately.
12. Links to Third-Party Websites
The Platform may contain links to external websites or third-party services. We are not responsible for their privacy practices or content. We encourage users to review the privacy policies of those third parties before engaging with them.
13. Grievance Officer
In accordance with the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011 and the Digital Personal Data Protection Act, 2023, the details of our Grievance Officer are as follows:
Name: [Insert Name]
Designation: Grievance Officer – Zyara Technologies Private Limited
Email: privacy@Zyara..
Address: [Insert Office Address]
We will acknowledge grievances within 24 hours and aim to resolve them within 30 days.
14. Changes to This Policy
We may modify this Policy periodically to reflect updates in our practices, legal obligations, or technological developments.
Revised versions will be posted on the Platform with a new “Last Updated” date.
Your continued use of Zyara after such updates constitutes your acceptance of the revised Policy.
15. Governing Law and Jurisdiction
This Policy is governed by and construed in accordance with the laws of India.
 Any disputes arising under this Policy shall be subject to the exclusive jurisdiction of the courts located in City, India.
''',
            style: TextStyle(color: _faint, height: 1.4, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
