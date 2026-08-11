import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/sim_provider.dart';
import '../widgets/common/app_widgets.dart';
import '../widgets/sim/sim_card_item.dart';

/// Page 4: List detected SIM cards and toggle which are active.
class SimCardsPage extends StatefulWidget {
  const SimCardsPage({super.key});

  @override
  State<SimCardsPage> createState() => _SimCardsPageState();
}

class _SimCardsPageState extends State<SimCardsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context.read<SimProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final sim = context.watch<SimProvider>();
    return SimGateScaffold(
      title: 'SIM Cards',
      body: RefreshIndicator(
        color: AppTheme.accentColor,
        onRefresh: _refresh,
        child: sim.isLoading && sim.sims.isEmpty
            ? const Center(child: LoadingIndicator())
            : sim.sims.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 64),
                      const Icon(Icons.sim_card_outlined,
                          size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'No SIM Cards Available',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: sim.sims.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SimCardItem(
                        sim: sim.sims[i],
                        onToggle: (value) async {
                          try {
                            await sim.toggle(sim.sims[i]);
                          } on StateError catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.message),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: _refresh,
        ),
      ],
    );
  }
}
