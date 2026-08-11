import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/sim_provider.dart';
import '../widgets/common/app_widgets.dart';
import '../widgets/sim/sim_card_item.dart';

/// Page 4: List detected SIM cards and toggle which are active.
///
/// When [inFlow] is true (onboarding), a Continue button is shown so the user
/// can pick the SIMs the gateway should use before moving on.
class SimCardsPage extends StatefulWidget {
  const SimCardsPage({super.key, this.inFlow = false});

  final bool inFlow;

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
                // ignore: prefer_const_literals_to_create_immutables
                children: [
                  const SizedBox(height: 64),
                  const Icon(
                    Icons.sim_card_outlined,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'No SIM Cards Available',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (widget.inFlow) ...[
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward,
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/config'),
                    ),
                  ],
                ],
              )
            : ListView.builder(
                itemCount: sim.sims.length + (widget.inFlow ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= sim.sims.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          PrimaryButton(
                            label: 'Continue',
                            icon: Icons.arrow_forward,
                            onPressed: sim.activeSims.isEmpty
                                ? null
                                : () => Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/config'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            sim.activeSims.isEmpty
                                ? 'Activate at least one SIM to continue'
                                : '${sim.activeSims.length} SIM(s) selected for the gateway',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SimCardItem(
                      sim: sim.sims[i],
                      onToggle: (value) async {
                        try {
                          await sim.toggle(sim.sims[i]);
                        } on StateError catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
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
