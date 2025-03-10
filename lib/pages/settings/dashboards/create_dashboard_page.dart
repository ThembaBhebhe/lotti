import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateDashboardPage extends StatefulWidget {
  const CreateDashboardPage({
    Key? key,
  }) : super(key: key);

  @override
  State<CreateDashboardPage> createState() => _CreateDashboardPageState();
}

class _CreateDashboardPageState extends State<CreateDashboardPage> {
  DashboardDefinition? _dashboardDefinition;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _dashboardDefinition = DashboardDefinition(
      id: uuid.v1(),
      name: '',
      createdAt: now,
      updatedAt: now,
      lastReviewed: now,
      description: '',
      vectorClock: null,
      version: '',
      items: [],
      active: true,
      private: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dashboardDefinition == null) {
      return const SizedBox.shrink();
    }
    return DashboardDetailPage(dashboard: _dashboardDefinition!);
  }
}
