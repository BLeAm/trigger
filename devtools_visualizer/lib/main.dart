import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const TriggerDevToolsApp());
}

class TriggerDevToolsApp extends StatelessWidget {
  const TriggerDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // หุ้มด้วย DevToolsExtension เพื่อให้เข้าถึง serviceManager ได้อัตโนมัติ
    return const DevToolsExtension(child: TriggerDashboard());
  }
}

class TriggerInspectorView extends StatelessWidget {
  const TriggerInspectorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Trigger DevTools',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            // ปุ่มทดสอบการเชื่อมต่อ
            ElevatedButton(
              onPressed: () async {
                // ตัวอย่างการเรียกไปถามฝั่ง App
                final response = await serviceManager
                    .callServiceExtensionOnMainIsolate('ext.trigger.getStates');
                print('Response from App: ${response.json}');
              },
              child: const Text('Check Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

// ใน devtools_visualizer
class TriggerDashboard extends StatefulWidget {
  const TriggerDashboard({super.key});

  @override
  State<TriggerDashboard> createState() => _TriggerDashboardState();
}

class _TriggerDashboardState extends State<TriggerDashboard> {
  List<dynamic> triggers = [];
  final Map<String, List<dynamic>> _previousValues = {};
  String _searchQuery = '';

  bool _showOnlyChanges = true; // เพิ่มตัวแปรสถานะใน State

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
        // เช็คว่ามีใครฟังอยู่หรือยัง ถ้ายังค่อยสั่ง listen
        await serviceManager.service?.streamListen('Extension');
      } catch (e) {
        // ถ้ามัน subscribe อยู่แล้ว (error 103) ก็ปล่อยผ่านไปครับ
        debugPrint('Extension stream already subscribed');
      }
    });
  }

  Future<void> refreshData() async {
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      'ext.trigger.getStates',
    );

    if (response.json != null) {
      setState(() {
        for (var t in triggers) {
          _previousValues[t['name']] = List.from(t['values']);
        }
        triggers = response.json!['triggers'] ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // กรอง Trigger ตามคำค้นหา (ค้นได้ทั้งชื่อ Trigger และชื่อ Field)
    final filteredTriggers = triggers.where((t) {
      final nameMatch = t['name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final fieldMatch = (t['fields'] as List).any(
        (f) => f.toString().toLowerCase().contains(_searchQuery.toLowerCase()),
      );
      return nameMatch || fieldMatch;
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trigger Live Inspector'),
          actions: [
            IconButton(onPressed: refreshData, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            // 1. Search Bar อยู่ใน Column ปกติ ไม่ต้องใช้ PreferredSize ใน AppBar
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Trigger or Field...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // 2. TabBar พร้อมตั้งค่า scrollable เพื่อแก้ Assertion Error
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.bolt), text: 'Live'),
                Tab(icon: Icon(Icons.history), text: 'History'),
                Tab(icon: Icon(Icons.analytics), text: 'Analysis'),
              ],
            ),

            // 3. ใช้ Expanded หุ้ม TabBarView เพื่อป้องกัน Overflow มหาศาล
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

  Widget _buildAnalysisView(List<dynamic> filtered) {
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final t = filtered[index];
        final impactMap = t['impactMap'] as Map<String, dynamic>;
        final rebuildStats = t['rebuildStats'] as Map<String, dynamic>;
        final listenCounts = t['listenCount'] as List? ?? [];

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ส่วนหัว: ชื่อ Trigger + ปุ่ม Actions ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Structure Analysis: ${t['name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // กลุ่มปุ่ม Action
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_sweep,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Clear Rebuild Stats',
                          onPressed: () async {
                            await serviceManager
                                .callServiceExtensionOnMainIsolate(
                                  'ext.trigger.executeAction',
                                  args: {
                                    'action': 'clearStats',
                                    'target': t['name'],
                                  },
                                );
                            refreshData();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),

                // --- 1. Health Check Warnings ---
                ...List.generate(listenCounts.length, (i) {
                  final count = listenCounts[i];
                  if (count > 10) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Field [${t['fields'][i]}] has $count listeners. High risk of lag.',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                const SizedBox(height: 16),
                const Text(
                  'Visualized Impact Graph:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (impactMap.isNotEmpty)
                  _buildVisualGraph(t['fields'], impactMap)
                else
                  const Text('No internal dependencies found.'),

                const SizedBox(height: 16),
                const Text(
                  'Dependency Table Details:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // --- 2. DataTable (Impact Map) ---
                if (impactMap.isEmpty)
                  const Text('No internal dependencies found.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.blueGrey.withOpacity(0.1),
                      ),
                      columns: const [
                        DataColumn(label: Text('Source Field')),
                        DataColumn(label: Text('➔')),
                        DataColumn(label: Text('Impacted Fields')),
                      ],
                      rows: impactMap.entries.map((e) {
                        final sourceIdx = int.tryParse(e.key) ?? 0;
                        final sourceName = t['fields'][sourceIdx];
                        final targets = (e.value as List)
                            .map((idx) => t['fields'][idx])
                            .join(', ');
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                sourceName,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const DataCell(
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                            DataCell(Text(targets)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 24),
                const Text(
                  '🔥 Rebuild Heatmap (Top Widgets):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),

                // --- 3. Rebuild Stats List ---
                if (rebuildStats.isEmpty)
                  const Text('No data collected.')
                else
                  ...rebuildStats.entries.map(
                    (e) => ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.whatshot,
                        color: e.value > 10 ? Colors.red : Colors.orange,
                      ),
                      title: Text(e.key),
                      trailing: Text(
                        '${e.value} times',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // หน้าจอหลัก: แสดง Chips ปัจจุบัน
  Widget _buildLiveView(List<dynamic> filtered) {
    if (filtered.isEmpty) {
      return const Center(child: Text('No triggers found.'));
    }

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
            trailing: const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.expand_more), // ไอคอนลูกศรเดิมของ ExpansionTile
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(t['values'].length, (i) {
                    final currentVal = t['values'][i];
                    final prevVals = _previousValues[t['name']];
                    final hasChanged =
                        prevVals != null &&
                        prevVals.length > i &&
                        prevVals[i] != currentVal;

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

  // หน้าจอประวัติ: แสดง Timeline การเปลี่ยนแปลง
  // หน้าจอประวัติ: แสดง Timeline การเปลี่ยนแปลง

  Widget _buildHistoryView(List<dynamic> filtered) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show only changed fields'),
          value: _showOnlyChanges,
          onChanged: (v) => setState(() => _showOnlyChanges = v),
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

                  // กรองเฉพาะ index ที่ค่าเปลี่ยน
                  List<int> changedIndices = [];
                  for (int i = 0; i < values.length; i++) {
                    if (prevValues == null || values[i] != prevValues[i]) {
                      changedIndices.add(i);
                    }
                  }

                  return ListTile(
                    onTap: () => _showLogDetail(context, t['name'], log),
                    title: Wrap(
                      spacing: 4,
                      children: List.generate(values.length, (i) {
                        final isChanged = changedIndices.contains(i);
                        if (_showOnlyChanges && !isChanged)
                          return const SizedBox.shrink();

                        return Chip(
                          label: Text(
                            '${fields[i]}: ${values[i]}',
                            style: const TextStyle(color: Colors.black),
                          ),
                          backgroundColor: isChanged
                              ? Colors.orange.shade100
                              : Colors.transparent,
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

  // Helper สำหรับดูรายละเอียด Log (กรณีค่าข้างในยาวอ่านยาก)
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

  // เพิ่ม Widget สำหรับวาดกราฟใน _buildAnalysisView
  // เพิ่ม Widget สำหรับวาดกราฟใน _buildAnalysisView
  Widget _buildVisualGraph(
    List<dynamic> fields,
    Map<String, dynamic> impactMap,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            color: Colors.black, // ปรับเป็นสีขาวเพื่อให้เด่นบนพื้นหลังเข้ม
            fontWeight: FontWeight.bold, // เพิ่มความหนาให้ดูง่ายขึ้น
            fontSize: 12,
          ),
        ),
        backgroundColor: _colorAnim.value,
      ),
    );
  }
}
