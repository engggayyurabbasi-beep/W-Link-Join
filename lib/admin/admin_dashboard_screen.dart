import 'package:material_ui/material_ui.dart';

import '../services/admin_auth_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const List<AdminModule> modules = [
    AdminModule('Overview & Analytics', Icons.dashboard_outlined),
    AdminModule('Group Management', Icons.groups_outlined),
    AdminModule('Pending Approvals', Icons.pending_actions),
    AdminModule('User Management', Icons.people_outline),
    AdminModule('Reports & Complaints', Icons.report_outlined),
    AdminModule('Support Tickets', Icons.support_agent),
    AdminModule('Featured Groups', Icons.star_outline),
    AdminModule('Announcements', Icons.campaign_outlined),
    AdminModule('Admin Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAuthService.isSuperAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          return const Scaffold(body: Center(child: Text('Access denied.')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('W-Link Join Admin'),
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await AdminAuthService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${module.title} module is coming next.'),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          module.icon,
                          size: 34,
                          color: const Color(0xFF16864A),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          module.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AdminModule {
  const AdminModule(this.title, this.icon);

  final String title;
  final IconData icon;
}
