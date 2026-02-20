part of '../trigger.dart';

class TriggerInspector<T extends Trigger> {
  T _trigger;
  final List<_StateChangeLog> _history = [];
  final int _maxHistory = 50;

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
        print('   └─> ${l}');
        // print('   └─> ${l.runtimeType}');
      }
    });
    print('-------------------------------------------\n');
  }

  void dumpDepsGraph({bool trace = false}) {
    print('=== Trigger Impact Tree [${_trigger.runtimeType}] ===');

    final impactMap = _trigger._impactMap;
    if (impactMap.isEmpty) {
      print('Empty graph');
      return;
    }
    // สร้าง Map กลับด้าน: Source -> List of Targets
    final reverseMap = <String, List<String>>{};
    impactMap.forEach((target, sources) {
      for (var src in sources) {
        reverseMap.putIfAbsent(src, () => []).add(target);
      }
    });

    final targetMap = trace ? impactMap : reverseMap;

    // 1. หา "Root Fields" (Field ที่ไม่มีใครสั่งมันมา)
    final allTargets = targetMap.values.expand((e) => e).toSet();
    final rootFields = targetMap.keys
        .where((field) => !allTargets.contains(field))
        .toList();
    rootFields.sort(); // เรียงชื่อให้สวยงาม

    // 2. ฟังก์ชัน Recursive สำหรับวาดกิ่ง
    void printNode(String node, String prefix, bool isLast) {
      // เลือกใช้สัญลักษณ์ให้เหมาะสม
      final marker = isLast ? '└── ' : '├── ';
      print('$prefix$marker$node');

      final children = targetMap[node]?.toList() ?? [];
      children.sort();

      // วาดลูกๆ ต่อลงไป
      for (int i = 0; i < children.length; i++) {
        final newPrefix = prefix + (isLast ? '    ' : '│   ');
        printNode(children[i], newPrefix, i == children.length - 1);
      }
    }

    // 3. เริ่มวาดจาก Root แต่ละตัว
    if (rootFields.isEmpty && targetMap.isNotEmpty) {
      // กรณีที่ทุกตัวเกี่ยวพันกันหมด (ซึ่งไม่น่าเกิดถ้าไม่มี cycle)
      print('Note: Complex dependency detected.');
      rootFields.addAll(targetMap.keys);
    }

    for (int i = 0; i < rootFields.length; i++) {
      printNode(rootFields[i], '', i == rootFields.length - 1);
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

  /// Enable to monitor batching update
  void logLive({bool enableHeatmap = true}) {
    _trigger._scheduler.addBatchHook((updatedStates) {
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
        // takeSnapshot();
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

  // ฟังก์ชันบันทึกที่สร้าง Object StateChangeLog
  void takeSnapshot([Set<String>? impacts]) {
    final log = _StateChangeLog(
      timestamp: DateTime.now(),
      values: Map<String, Object?>.from(_trigger._values),
      impactFields: impacts,
    );

    _history.add(log);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  // 2.3 ฟังก์ชันย้อนกลับ
  void undo() {
    if (_history.length < 2) return; // ไม่มีอะไรให้ย้อน หรือมีแค่ค่าปัจจุบัน

    _history.removeLast(); // เอาค่าปัจจุบันออก
    final previousState = _history.last;

    // ยัดค่ากลับเข้า Trigger ผ่าน setMultiValues เพื่อกระตุ้น UI ครั้งเดียว
    _trigger.setMultiValues(previousState.values);
  }

  void enableSnapshot() =>
      _trigger._scheduler.addBatchHook((_) => takeSnapshot());

  // ระบบ Report ที่ดึงข้อมูลจาก Log Class มาแสดง
  void printHistoryReport() {
    print('\n📜 [History Report] ${_trigger.runtimeType}');
    print('-------------------------------------------');

    for (int i = 0; i < _history.length; i++) {
      final log = _history[i];
      final prevLog = i > 0 ? _history[i - 1] : null;
      final timeStr =
          "${log.timestamp.minute}:${log.timestamp.second}.${log.timestamp.millisecond}";

      print('Step [$i] @ $timeStr');
      log.values.forEach((key, value) {
        // ถ้าค่าไม่เหมือนเดิม ให้ใส่เครื่องหมาย 🟡 หรือถ้าเป็น Snapshot แรกให้พิมพ์ปกติ
        final isChanged = prevLog == null || prevLog.values[key] != value;
        final prefix = isChanged ? '🟡 ' : '   ';
        print('$prefix${key.padRight(12)} : $value');
      });
      print('-------------------------------------------');
    }
  }
}

class _StateChangeLog {
  final DateTime timestamp;
  final Map<String, Object?> values;
  // เก็บไว้ว่า Snapshot นี้เกิดจากการแก้ Field ไหนบ้าง (Optional แต่ช่วยให้ Report สวย)
  final Set<String>? impactFields;

  _StateChangeLog({
    required this.timestamp,
    required this.values,
    this.impactFields,
  });
}
