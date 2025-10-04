import 'package:flutter/material.dart';

import '../services/session_cost_service.dart';

class SessionCostBottomSheet extends StatelessWidget {
  final SessionCostService sessionCostService;
  final ScrollController scrollController;
  final Map<String, dynamic>? additionalCostData;

  const SessionCostBottomSheet({
    super.key,
    required this.sessionCostService,
    required this.scrollController,
    this.additionalCostData,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<SessionCostData>(
          stream: sessionCostService.costUpdates,
          builder: (context, snapshot) {
            final data = snapshot.data ??
                const SessionCostData(sessionCost: 0, lastMessageCost: 0, messageCount: 0);
            return ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Session Cost', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Messages: ${data.messageCount}'),
                Text('Session total: ${data.sessionCost.toStringAsFixed(4)}'),
                Text('Last message: ${data.lastMessageCost.toStringAsFixed(4)}'),
                if (additionalCostData != null) ...[
                  const SizedBox(height: 12),
                  Text('Details', style: Theme.of(context).textTheme.titleSmall),
                  Text(additionalCostData.toString()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

