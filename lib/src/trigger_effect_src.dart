part of '../trigger.dart';

// --- ยกเลิกการใช้ _getDeepAncestors (แบบ Recursion) ---

abstract base class TriggerEffect<T extends Trigger> implements Updateable {
  late T _trigger;
  @protected
  T get trigger => _trigger;

  // เปลี่ยนเป็น List<int> แทน String
  TriggerFields<T> get listenTo;
  TriggerFields<T> get allowedMutate;

  late final Set<int> _allowedMutate;

  void checkAllow(int index) {
    if (!_allowedMutate.contains(index)) {
      throw StateError(
        "Access Denied: Mutation of index '$index' (${_trigger._fieldNames[index]}) is restricted.",
      );
    }
  }

  TriggerEffect(T trigger) {
    _trigger = trigger;
    final listenToIdx = listenTo.getList();
    final mutateIdx = allowedMutate.getList();
    _allowedMutate = mutateIdx.toSet();

    // 1. ตรวจสอบ Cycle สำหรับทุกๆ key ที่เรากำลังจะ "ฟัง" (Listen)
    // BFS Cycle Detection using Integers
    for (final lIdx in listenToIdx) {
      _verifyNoPathToTargets(lIdx, _allowedMutate, _trigger._impactMap);
    }

    // 2. ถ้าผ่านการเช็ค (ไม่มี Error) ให้บันทึกความสัมพันธ์ลงใน _impactMap ของ Trigger
    // บันทึกว่า: ถ้า mKey เปลี่ยน (Mutate) จะส่งผลกระทบย้อนกลับไปหาต้นตอ (lKey)
    // Record Impacts
    for (final mIdx in _allowedMutate) {
      final impactSet = _trigger._impactMap.putIfAbsent(mIdx, () => {});
      for (final lIdx in listenToIdx) {
        impactSet.add(lIdx);
      }
    }

    // 3. เริ่มฟังค่า (Listen) ตามปกติ
    for (final lIdx in listenToIdx) {
      _trigger.listenTo(lIdx, this);
    }
  }

  /// ฟังก์ชันใหม่: ใช้ BFS หาทางเดินจาก start ไปยังกลุ่มเป้าหมาย (targetKeys)
  void _verifyNoPathToTargets(
    int startIdx,
    Set<int> targets,
    Map<int, Set<int>> map,
  ) {
    // กรณีพื้นฐาน: ถ้าต้นตอ (Listen) กับเป้าหมาย (Mutate) เป็นตัวเดียวกัน
    if (targets.contains(startIdx)) _throwCycleError(startIdx, startIdx);

    final queue = Queue<int>()..add(startIdx);
    final visited = <int>{startIdx};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final neighbors = map[current];

      if (neighbors != null) {
        for (final next in neighbors) {
          if (targets.contains(next)) _throwCycleError(startIdx, next);
          if (!visited.contains(next)) {
            visited.add(next);
            queue.add(next);
          }
        }
      }
    }
  }

  void _throwCycleError(int listen, int mutate) {
    final lName = _trigger._fieldNames[listen];
    final mName = _trigger._fieldNames[mutate];
    throw StateError("Cyclic update detected: '$lName' <-> '$mName'");
  }

  void onTrigger();
  void update() => onTrigger();
}
