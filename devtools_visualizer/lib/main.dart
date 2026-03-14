import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_trigger/trigger_widgets.dart';
import 'extension_states.dart';

void main() {
  runApp(
    TriggerScope(
      triggers: [ExtensionStates()],
      child: const TriggerDevToolsApp(),
    ),
  );
}

class TriggerDevToolsApp extends StatelessWidget {
  const TriggerDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: TriggerDashboard());
  }
}

class TriggerDashboard extends StatefulWidget {
  const TriggerDashboard({super.key});

  @override
  State<TriggerDashboard> createState() => _TriggerDashboardState();
}

class _TriggerDashboardState extends State<TriggerDashboard>
    with TriggerStateMixin<TriggerDashboard, ExtensionStates> {
  @override
  final listenTo = ExtensionStates.fields.triggers.searchQuery.showOnlyChanges;

  @override
  void initState() {
    super.initState();
    _setupAutoRefresh();
  }

  void _setupAutoRefresh() {
    serviceManager.onServiceAvailable.then((_) async {
      serviceManager.service?.onExtensionEvent.listen((event) {
        if (event.extensionKind == 'trigger:update') {
          refreshData();
        }
      });
      try {
        await serviceManager.service?.streamListen('Extension');
      } catch (e) {
        debugPrint('Extension stream already subscribed');
      }
    });
  }

  Future<void> refreshData() async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      'ext.trigger.getStates',
    );

    if (response.json != null) {
      final newTriggersRaw = response.json!['triggers'] as List? ?? [];

      trigger.multiSet((s) {
        final newPrevMap = <String, List<dynamic>>{};
        for (var t in trigger.triggers) {
          newPrevMap[t['name'].toString()] = List<dynamic>.from(t['values']);
        }
        s
          ..previousValues = newPrevMap
          ..triggers = List<dynamic>.from(newTriggersRaw);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTriggers = trigger.triggers.where((t) {
      final query = trigger.searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final nameMatch = t['name'].toString().toLowerCase().contains(query);
      final fieldMatch = (t['fields'] as List).any(
        (f) => f.toString().toLowerCase().contains(query),
      );
      return nameMatch || fieldMatch;
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trigger Live Inspector'),
          actions: [
            // --- เพิ่มปุ่ม Check Connection ตรงนี้เพื่อความสะดวก ---
            TextButton.icon(
              onPressed: () async {
                final res = await serviceManager
                    .callServiceExtensionOnMainIsolate('ext.trigger.getStates');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Connection: ${res.json != null ? "Success" : "Failed"}',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.link, color: Colors.white),
              label: const Text('Check', style: TextStyle(color: Colors.white)),
            ),
            IconButton(onPressed: refreshData, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search Trigger or Field...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => trigger.searchQuery = val,
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.bolt), text: 'Live'),
                Tab(icon: Icon(Icons.history), text: 'History'),
                Tab(icon: Icon(Icons.analytics), text: 'Analysis'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLiveView(filteredTriggers),
                  _buildHistoryView(filteredTriggers),
                  _buildAnalysisView(filteredTriggers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Live View ---
  Widget _buildLiveView(List<dynamic> filtered) {
    if (filtered.isEmpty)
      return const Center(child: Text('No triggers found.'));
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final t = filtered[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              t['name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(t['values'].length, (i) {
                    final currentVal = t['values'][i];
                    final prevVals = trigger.previousValues[t['name']];
                    final hasChanged =
                        prevVals != null &&
                        prevVals.length > i &&
                        prevVals[i].toString() != currentVal.toString();
                    return HighlightChip(
                      label: '${t['fields'][i]}: $currentVal',
                      isChanged: hasChanged,
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. History View ---
  Widget _buildHistoryView(List<dynamic> filtered) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show only changed fields'),
          value: trigger.showOnlyChanges,
          onChanged: (v) => trigger.showOnlyChanges = v,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final t = filtered[index];
              final history = t['history'] as List? ?? [];
              final fields = t['fields'] as List;
              return ExpansionTile(
                title: Text('History: ${t['name']}'),
                children: history.reversed.take(20).map<Widget>((log) {
                  final values = log['values'] as List;
                  final prevValues = log['prevValues'] as List?;
                  return ListTile(
                    onTap: () => _showLogDetail(context, t['name'], log),
                    title: Wrap(
                      spacing: 4,
                      children: List.generate(values.length, (i) {
                        final isChanged =
                            prevValues == null || values[i] != prevValues[i];
                        if (trigger.showOnlyChanges && !isChanged)
                          return const SizedBox.shrink();
                        return Chip(
                          label: Text('${fields[i]}: ${values[i]}'),
                          backgroundColor: isChanged
                              ? Colors.orange.shade100
                              : null,
                          shape: isChanged
                              ? null
                              : const StadiumBorder(
                                  side: BorderSide(color: Colors.grey),
                                ),
                        );
                      }),
                    ),
                    subtitle: Text(log['time'].toString().split('T').last),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 3. Analysis View (เพิ่ม DataTable กลับมา) ---
  Widget _buildAnalysisView(List<dynamic> filtered) {
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final t = filtered[index];
        final impactMap = t['impactMap'] as Map<String, dynamic>? ?? {};
        final rebuildStats = t['rebuildStats'] as Map<String, dynamic>? ?? {};
        final listenCounts = t['listenCount'] as List? ?? [];

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Analysis: ${t['name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Clear Stats',
                      onPressed: () async {
                        await serviceManager.callServiceExtensionOnMainIsolate(
                          'ext.trigger.executeAction',
                          args: {'action': 'clearStats', 'target': t['name']},
                        );
                        refreshData();
                      },
                    ),
                  ],
                ),
                const Divider(),
                // Health Check
                ...List.generate(listenCounts.length, (i) {
                  if (listenCounts[i] > 10) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Field [${t['fields'][i]}] has ${listenCounts[i]} listeners.',
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 16),
                const Text(
                  'Visual Impact Graph:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (impactMap.isNotEmpty)
                  _buildVisualGraph(t['fields'], impactMap)
                else
                  const Text('No dependencies found.'),

                // --- ส่วนที่กู้คืนมา: DataTable ---
                const SizedBox(height: 24),
                const Text(
                  'Dependency Details Table:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (impactMap.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Source')),
                        DataColumn(label: Text('➔')),
                        DataColumn(label: Text('Impacted')),
                      ],
                      rows: impactMap.entries.map((e) {
                        final sourceIdx = int.parse(e.key);
                        final targets = (e.value as List)
                            .map((idx) => t['fields'][idx])
                            .join(', ');
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                t['fields'][sourceIdx],
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                            const DataCell(Icon(Icons.arrow_forward, size: 14)),
                            DataCell(Text(targets)),
                          ],
                        );
                      }).toList(),
                    ),
                  )
                else
                  const Text('No detailed data available.'),

                const SizedBox(height: 24),
                const Text(
                  '🔥 Rebuild Heatmap:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...rebuildStats.entries.map(
                  (e) => ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.whatshot,
                      color: e.value > 10 ? Colors.red : Colors.orange,
                    ),
                    title: Text(e.key),
                    trailing: Text('${e.value} times'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisualGraph(
    List<dynamic> fields,
    Map<String, dynamic> impactMap,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: impactMap.entries.map((entry) {
          final sourceIdx = int.parse(entry.key);
          final targets = entry.value as List;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _nodeBox(fields[sourceIdx], Colors.blue),
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: targets
                        .map((tIdx) => _nodeBox(fields[tIdx], Colors.green))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _nodeBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showLogDetail(BuildContext context, String name, dynamic log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Snapshot: $name'),
        content: SingleChildScrollView(child: Text(log['values'].join('\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class HighlightChip extends StatefulWidget {
  final String label;
  final bool isChanged;
  const HighlightChip({
    super.key,
    required this.label,
    required this.isChanged,
  });
  @override
  State<HighlightChip> createState() => _HighlightChipState();
}

class _HighlightChipState extends State<HighlightChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _colorAnim = ColorTween(
      begin: Colors.blueGrey.shade50,
      end: Colors.orange.shade200,
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(HighlightChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChanged) {
      _controller.forward(from: 0).then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, child) => Chip(
        label: Text(
          widget.label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: _colorAnim.value,
      ),
    );
  }
}
