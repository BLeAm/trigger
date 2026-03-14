part of '../trigger.dart';

class TriggerInspector<T extends Trigger> {
  static final List<TriggerInspector> _allInspectors = [];

  static void init() {
    developer.registerExtension('ext.trigger.getStates', (
      method,
      parameters,
    ) async {
      final data = _allInspectors.map((inspector) {
        return {
          'name': inspector._trigger.runtimeType.toString(),
          'values': inspector._trigger._values
              .map((v) => v.toString())
              .toList(),
          'fields': inspector._trigger._fieldNames,
          // ส่งประวัติ 10 รายการล่าสุดไปด้วย!
          'history': inspector._history.reversed
              // เพิ่มการส่งค่า 'previousValues' เพื่อให้ UI คำนวณ Diff ได้ง่ายขึ้น
              .map((log) {
                final index = inspector._history.indexOf(log);
                final prevLog = index > 0
                    ? inspector._history[index - 1]
                    : null;
                return {
                  'time': log.timestamp.toIso8601String(),
                  'values': log.values.map((v) => v.toString()).toList(),
                  'prevValues': prevLog?.values
                      .map((v) => v.toString())
                      .toList(),
                };
              })
              .toList(),
          'impactMap': inspector._trigger._impactMap.map(
            (k, v) => MapEntry(k.toString(), v.toList()),
          ),
          'listenCount': inspector._trigger._listenMap
              .map((l) => l.length)
              .toList(),
          'rebuildStats': inspector._rebuildStats.map(
            (k, v) => MapEntry(k.toString(), v),
          ),
        };
      }).toList();

      return developer.ServiceExtensionResponse.result(
        jsonEncode({'triggers': data}),
      );
    });

    developer.registerExtension('ext.trigger.executeAction', (
      method,
      parameters,
    ) async {
      final action = parameters['action'];
      // final targetName = parameters['target'];

      for (var inspector in _allInspectors) {
        if (action == 'clearStats') {
          inspector.clearRebuildStats();
        }
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'success': true}),
      );
    });
  }

  T _trigger;
  final List<_StateChangeLog> _history = [];
  final int _maxHistory = 50;

  TriggerInspector(T trigger) : _trigger = trigger {
    if (!_allInspectors.any((ins) => ins._trigger == trigger)) {
      _allInspectors.add(this);
    }

    // --- ส่วน Real-time: ฟังการเปลี่ยนค่าแล้ว "ตะโกน" บอก DevTools ---
    _trigger._scheduler.addBatchHook((_) {
      // ส่ง Event พิเศษออกไปทาง VM Service
      developer.postEvent('trigger:update', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  // เก็บสถิติ: ประเภท Widget -> จำนวนครั้งที่ rebuild
  final Map<Type, int> _rebuildStats = {};

  // --- Helper: แปลง Index เป็น Name หรือเลข Index ถ้าหาไม่เจอ ---
  String _nameOf(int index) => _trigger._fieldNames[index];

  void printValuesTable() {
    print('\n📊 Values Table [${_trigger.runtimeType}]');
    print('-------------------------------------------');
    for (int i = 0; i < _trigger._values.length; i++) {
      final name = _nameOf(i);
      final value = _trigger._values[i];
      print('${name.padRight(15)} : $value (${value.runtimeType})');
    }
    print('-------------------------------------------\n');
  }

  void printListenTable() {
    print('\n👂 Listen Table (Who is listening to what?)');
    print('-------------------------------------------');
    for (int i = 0; i < _trigger._listenMap.length; i++) {
      final name = _nameOf(i);
      final listeners = _trigger._listenMap[i];
      if (listeners.isEmpty) continue;

      print('${name.padRight(15)} : ${listeners.length} listeners');
      for (var l in listeners) {
        print('   └─> $l');
      }
    }
    print('-------------------------------------------\n');
  }

  void dumpDepsGraph({bool trace = false}) {
    print('=== Trigger Impact Tree [${_trigger.runtimeType}] ===');

    final impactMap = _trigger._impactMap;
    if (impactMap.isEmpty) {
      print('Empty graph');
      return;
    }

    // สร้าง Map: SourceIndex -> List<TargetIndex>
    // trace = true:  Mutate -> ผลกระทบไปที่ไหนบ้าง
    // trace = false: Listen -> ถูกกระตุ้นโดยอะไรบ้าง
    final Map<int, List<int>> targetMap = {};
    if (trace) {
      impactMap.forEach((mIdx, lIndices) {
        targetMap[mIdx] = lIndices.toList();
      });
    } else {
      impactMap.forEach((mIdx, lIndices) {
        for (var lIdx in lIndices) {
          targetMap.putIfAbsent(lIdx, () => []).add(mIdx);
        }
      });
    }

    final allTargets = targetMap.values.expand((e) => e).toSet();
    final rootIndices = targetMap.keys
        .where((idx) => !allTargets.contains(idx))
        .toList();

    void printNode(int idx, String prefix, bool isLast) {
      final marker = isLast ? '└── ' : '├── ';
      print('$prefix$marker${_nameOf(idx)}');

      final children = targetMap[idx] ?? [];
      for (int i = 0; i < children.length; i++) {
        final newPrefix = prefix + (isLast ? '    ' : '│   ');
        printNode(children[i], newPrefix, i == children.length - 1);
      }
    }

    for (int i = 0; i < rootIndices.length; i++) {
      printNode(rootIndices[i], '', i == rootIndices.length - 1);
    }
    print('==============================================');
  }

  // Helper สำหรับสี Console
  String _color(String text, String code) => '\x1B[${code}m$text\x1B[0m';
  String get _red => '31';
  // String get _green => '32';
  String get _yellow => '33';
  String get _cyan => '36';

  void analyzeHealth() {
    print('\n${_color('🩺 [Health Report] ${_trigger.runtimeType}', _cyan)}');
    print('-------------------------------------------');

    bool isHealthy = true;

    // 1. ตรวจสอบโครงสร้าง
    for (int i = 0; i < _trigger._listenMap.length; i++) {
      final listeners = _trigger._listenMap[i];
      if (listeners.length > 10) {
        isHealthy = false;
        print(
          '${_color('⚠️ Structure:', _yellow)} Key [${_nameOf(i)}] has too many listeners (${listeners.length}).',
        );
      }
    }

    // 2. ตรวจสอบพฤติกรรม
    final hotWidgets = _rebuildStats.entries.where((e) => e.value > 50);
    if (hotWidgets.isNotEmpty) {
      isHealthy = false;
      for (var entry in hotWidgets) {
        print(
          '${_color('🔥 Runtime:', _red)} Widget [${entry.key}] is rebuilding very often (${entry.value} times).',
        );
      }
    }
    // 3. ตรวจสอบส่วนเกิน (Orphans) - Field ที่ไม่มีใครฟังเลย
    final orphans = <String>[];
    for (int i = 0; i < _trigger._values.length; i++) {
      // ใน List-based เราเช็คว่า Set ใน _listenMap ว่างหรือไม่
      if (_trigger._listenMap[i].isEmpty) {
        orphans.add(_nameOf(i));
      }
    }

    if (orphans.isNotEmpty) {
      print(
        'ℹ️ Optimization: Fields with no listeners (consider removing): ${orphans.join(", ")}',
      );
    }

    if (isHealthy) {
      print(
        '✅ Everything looks great. The graph is lean and updates are stable.',
      );
    }
    print('-------------------------------------------\n');
  }

  /// Enable to monitor batching update
  void logLive({bool enableHeatmap = true}) {
    _trigger._scheduler.addBatchHook((updatedStates) {
      final myWidgets = updatedStates.where(
        (s) => _trigger._reverseListenMap.containsKey(s),
      );
      if (myWidgets.isNotEmpty) {
        if (enableHeatmap) {
          for (var s in myWidgets) {
            _rebuildStats[s.runtimeType] =
                (_rebuildStats[s.runtimeType] ?? 0) + 1;
          }
        }
        print(
          '🔔 [${_trigger.runtimeType}] Batch Update: ${myWidgets.length} widgets rebuilt.',
        );
      }
    });
  }

  void printRebuildRank() {
    if (_rebuildStats.isEmpty) {
      print('📉 No rebuild data collected yet.');
      return;
    }

    // เรียงลำดับจากมากไปน้อย
    final sorted = _rebuildStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print('\n🔥 Rebuild Heatmap Rank (Most Active First)');
    print('-------------------------------------------');
    for (var entry in sorted) {
      final rank = entry.value > 10 ? '🔴' : (entry.value > 5 ? '🟡' : '🟢');
      print(
        '$rank ${entry.key.toString().padRight(25)} : ${entry.value} times',
      );
    }
    print('-------------------------------------------\n');
  }

  void showMaxDepth() {
    final impactMap = _trigger._impactMap;
    if (impactMap.isEmpty) {
      print('📏 Max Graph Depth: 0 (No dependencies)');
      return;
    }

    // เปลี่ยนจาก String field เป็น int index
    int getDepth(int idx, Set<int> visited) {
      if (!impactMap.containsKey(idx)) return 0;
      if (visited.contains(idx))
        return 0; // กัน Cycle (ซึ่งดักไว้แล้วตอนสร้าง Effect)

      visited.add(idx);
      int maxChildDepth = 0;

      // วนลูปตามกลุ่มของ Listener Indices ที่ได้รับผลกระทบ
      for (var dependentIdx in impactMap[idx]!) {
        final d = getDepth(dependentIdx, visited);
        if (d > maxChildDepth) maxChildDepth = d;
      }
      visited.remove(idx);

      return 1 + maxChildDepth;
    }

    int overallMax = 0;
    // วนลูปหา Depth จากทุก Key ที่อยู่ใน Impact Map
    for (var idx in impactMap.keys) {
      final d = getDepth(idx, {});
      if (d > overallMax) overallMax = d;
    }

    print('\n⛓️ Dependency Analysis');
    print('-------------------------------------------');
    print('Maximum Propagation Depth: $overallMax hops');
    if (overallMax > 4) {
      print('⚠️ Warning: High depth detected. Logic may be too fragmented.');
    } else {
      print('✅ Graph structure is shallow and efficient.');
    }
    print('-------------------------------------------\n');
  }

  void clearRebuildStats() {
    _rebuildStats.clear();
    print('🧹 Rebuild stats cleared.');
  }

  // ฟังก์ชันบันทึกที่สร้าง Object StateChangeLog
  // --- Snapshot Logic (ใช้ Map<int, Object?> เพื่อประหยัดพื้นที่กว่าเก็บ List เต็ม) ---
  void takeSnapshot([Set<int>? impacts]) {
    final log = _StateChangeLog(
      timestamp: DateTime.now(),
      // เก็บเป็น List<Object?> เหมือนโครงสร้างจริง
      values: List<Object?>.from(_trigger._values),
      impactIndices: impacts,
    );
    _history.add(log);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  void enableSnapshot() =>
      _trigger._scheduler.addBatchHook((_) => takeSnapshot());

  // ระบบ Report ที่ดึงข้อมูลจาก Log Class มาแสดง
  void printHistoryReport() {
    print('\n📜 [History Report] ${_trigger.runtimeType}');
    for (int i = 0; i < _history.length; i++) {
      final log = _history[i];
      final prev = i > 0 ? _history[i - 1] : null;
      print('Step [$i] @ ${log.timestamp.second}.${log.timestamp.millisecond}');

      for (int j = 0; j < log.values.length; j++) {
        final isChanged = prev == null || prev.values[j] != log.values[j];
        final prefix = isChanged ? '🟡 ' : '   ';
        print('$prefix${_nameOf(j).padRight(12)} : ${log.values[j]}');
      }
      print('-------------------------------------------');
    }
  }

  // --- ส่วน Clean-up: ลบตัวเองออกจากลิสต์เมื่อไม่ใช้แล้ว ---
  void dispose() {
    _allInspectors.remove(this);
  }
}

class _StateChangeLog {
  final DateTime timestamp;
  final List<Object?> values; // เก็บเป็น List ตามโครงสร้างใหม่
  final Set<int>? impactIndices;

  _StateChangeLog({
    required this.timestamp,
    required this.values,
    this.impactIndices,
  });
}
