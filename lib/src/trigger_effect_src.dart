part of '../trigger.dart';

// --- ยกเลิกการใช้ _getDeepAncestors (แบบ Recursion) ---

abstract base class TriggerEffect<T extends Trigger> implements Updateable {
  late T _trigger;
  @protected
  T get trigger => _trigger;

  TriggerFields<T> get listenTo;
  TriggerFields<T> get allowedMutate;

  late final List<String> _listenTo;
  late final Set<String> _allowedMutate;

  void checkAllow(String key) {
    if (!_allowedMutate.contains(key)) {
      throw StateError(
        "Access Denied: Mutation of key '$key' is restricted. Only keys in [${_allowedMutate.join(', ')}] are allowed.",
      );
    }
  }

  TriggerEffect(T trigger) {
    _trigger = trigger;
    _listenTo = listenTo.getList();
    _allowedMutate = allowedMutate.getList().toSet();

    // 1. ตรวจสอบ Cycle สำหรับทุกๆ key ที่เรากำลังจะ "ฟัง" (Listen)
    for (final lKey in _listenTo) {
      _verifyNoPathToTargets(lKey, _allowedMutate, this.trigger._impactMap);
    }

    // 2. ถ้าผ่านการเช็ค (ไม่มี Error) ให้บันทึกความสัมพันธ์ลงใน _impactMap ของ Trigger
    // บันทึกว่า: ถ้า mKey เปลี่ยน (Mutate) จะส่งผลกระทบย้อนกลับไปหาต้นตอ (lKey)
    for (final mKey in _allowedMutate) {
      final impactSet = this.trigger._impactMap.putIfAbsent(mKey, () => {});
      for (final lKey in _listenTo) {
        impactSet.add(lKey);
      }
    }

    // 3. เริ่มฟังค่า (Listen) ตามปกติ
    for (final lKey in _listenTo) {
      this.trigger.listenTo(lKey, this);
    }
  }

  /// ฟังก์ชันใหม่: ใช้ BFS หาทางเดินจาก start ไปยังกลุ่มเป้าหมาย (targetKeys)
  void _verifyNoPathToTargets(
    String startKey,
    Set<String> targetKeys,
    Map<String, Set<String>> map,
  ) {
    // กรณีพื้นฐาน: ถ้าต้นตอ (Listen) กับเป้าหมาย (Mutate) เป็นตัวเดียวกัน
    if (targetKeys.contains(startKey)) {
      _throwCycleError(startKey, startKey);
    }

    final queue = Queue<String>()..add(startKey);
    final visited = <String>{startKey};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final neighbors = map[current];

      if (neighbors != null) {
        for (final next in neighbors) {
          // ถ้าเจอว่าเพื่อนบ้านตัวไหนอยู่ในกลุ่มเป้าหมาย แปลว่าเกิด Cycle
          if (targetKeys.contains(next)) {
            _throwCycleError(startKey, next);
          }

          // ถ้ายังไม่เคยไปที่ Node นี้ ให้ใส่ Queue เพื่อค้นหาต่อ
          if (!visited.contains(next)) {
            visited.add(next);
            queue.add(next);
          }
        }
      }
    }
  }

  void _throwCycleError(String listen, String mutate) {
    throw StateError(
      "Cyclic update detected: This effect listens to '$listen' but tries to mutate '$mutate', "
      "which eventually impacts '$listen' again (Circular Dependency).",
    );
  }

  void onTrigger();

  void update() {
    onTrigger();
  }
}
