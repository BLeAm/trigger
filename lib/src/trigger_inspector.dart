part of '../trigger.dart';

class TriggerInspector<T extends Trigger> {
  T _trigger;

  TriggerInspector(T trigger) : _trigger = trigger;

  // เก็บสถิติ: ประเภท Widget -> จำนวนครั้งที่ rebuild
  final Map<Type, int> _rebuildStats = {};

  void printValuesTable() {
    print('\n📊 Values Table [${_trigger.runtimeType}]');
    print('-------------------------------------------');
    _trigger._values.forEach((key, value) {
      print('${key.padRight(15)} : $value (${value.runtimeType})');
    });
    print('-------------------------------------------\n');
  }

  void printListenTable() {
    print('\n👂 Listen Table (Who is listening to what?)');
    print('-------------------------------------------');
    _trigger._listenMap.forEach((key, listeners) {
      print('${key.padRight(15)} : ${listeners.length} listeners');
      for (var l in listeners) {
        print('   └─> ${l.runtimeType}');
      }
    });
    print('-------------------------------------------\n');
  }

  void dumpDepsGraph() {
    print('=== Trigger Impact Graph [${_trigger.runtimeType}] ===');
    if (_trigger._impactMap.isEmpty) {
      print('Empty graph');
      return;
    }
    final sortedKeys = _trigger._impactMap.keys.toList()..sort();
    for (final mKey in sortedKeys) {
      final listeners = _trigger._impactMap[mKey]!;
      final sortedListeners = listeners.toList()..sort();
      print('  $mKey ⟸ [${sortedListeners.join(', ')}]');
    }
    print('==============================================');
  }

  void analyzeHealth() {
    print('\n🩺 [Health Report] ${_trigger.runtimeType}');
    print('-------------------------------------------');

    bool isHealthy = true;

    // 1. ตรวจสอบโครงสร้าง (Static)
    final overCrowded = _trigger._listenMap.entries.where(
      (e) => e.value.length > 10,
    );
    if (overCrowded.isNotEmpty) {
      isHealthy = false;
      for (var entry in overCrowded) {
        print(
          '⚠️ Structure: Key [${entry.key}] has too many listeners (${entry.value.length}).',
        );
      }
    }

    // 2. ตรวจสอบพฤติกรรม (Runtime - จาก Heatmap)
    final hotWidgets = _rebuildStats.entries.where(
      (e) => e.value > 50,
    ); // สมมติว่าเกิน 50 คือร้อน
    if (hotWidgets.isNotEmpty) {
      isHealthy = false;
      for (var entry in hotWidgets) {
        print(
          '🔥 Runtime: Widget [${entry.key}] is rebuilding very often (${entry.value} times).',
        );
      }
    }

    // 3. ตรวจสอบส่วนเกิน (Orphans)
    final orphans = _trigger._values.keys.where(
      (k) => !_trigger._listenMap.containsKey(k),
    );
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

  // ฟังก์ชันสำหรับเสียบระบบ Log/Monitor แบบ Custom
  void attachBatchMonitor(BatchUpdateHook monitor) {
    _trigger._scheduler.onBatchUpdate = monitor;
  }

  /// Enable to monitor batching update
  void logLive({bool enableHeatmap = true}) {
    attachBatchMonitor((updatedStates) {
      final myWidgets = updatedStates.where(
        (s) => _trigger._reverseListenMap.containsKey(s),
      );

      if (myWidgets.isNotEmpty) {
        if (enableHeatmap) {
          for (var s in myWidgets) {
            final type = s.runtimeType;
            _rebuildStats[type] = (_rebuildStats[type] ?? 0) + 1;
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

    int getDepth(String field, Set<String> visited) {
      if (!impactMap.containsKey(field)) return 0;
      if (visited.contains(field))
        return 0; // กันตายถ้ามี cycle (แต่ปกติเราดักไว้แล้ว)

      visited.add(field);
      int maxChildDepth = 0;
      for (var dependent in impactMap[field]!) {
        final d = getDepth(dependent, visited);
        if (d > maxChildDepth) maxChildDepth = d;
      }
      visited.remove(field);

      return 1 + maxChildDepth;
    }

    int overallMax = 0;
    for (var field in impactMap.keys) {
      final d = getDepth(field, {});
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
}
