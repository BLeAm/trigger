part of '../trigger.dart';

Set<String> _getDeepAncestors(
  String key,
  Map<String, Set<String>> map,
  Set<String> visited,
) {
  if (!map.containsKey(key) || visited.contains(key)) return {};

  visited.add(key); // จดชื่อว่ากำลังเดินผ่าน

  final results = <String>{...map[key]!};
  for (final ancestor in map[key]!) {
    results.addAll(_getDeepAncestors(ancestor, map, visited));
  }

  visited.remove(key); // <--- ถอนชื่อออกเพื่อให้กิ่งอื่นเข้าถึงได้
  return results;
}

abstract base class TriggerEffect<T extends Trigger> implements Updateable {
  T _trigger = Trigger.of<T>();
  @protected
  T get effectTrigger => _trigger;
  TriggerFields<T> listenTo();
  TriggerFields<T> allowedMutate();

  late final List<String> _listenTo;
  late final Set<String> _allowedMutate;

  void checkAllow(String key) {
    if (!_allowedMutate.contains(key))
      throw StateError(
        "Access Denied: Mutation of key '$key' is restricted. Only keys in [${_allowedMutate.join(', ')}] are allowed.",
      );
  }

  // TriggerEffect([T? etrig = null]) {
  //   if (etrig != null) {
  //     _trigger = etrig;
  //   }
  //   _listenTo = listenTo().toList();
  //   _allowedMutate = allowedMutate().toSet();

  //   for (final key in _allowedMutate) {
  //     if (!effectTrigger._cyclicDetect.containsKey(key)) {
  //       effectTrigger._cyclicDetect[key] = {};
  //     }
  //     effectTrigger._cyclicDetect[key]!.addAll(_listenTo);
  //     _allowedMutate.add(key);
  //   }
  //   for (final key in _listenTo) {
  //     if (!effectTrigger._cyclicDetect.containsKey(key)) {
  //       effectTrigger._cyclicDetect[key] = {};
  //     }
  //     final ckey = effectTrigger._cyclicDetect[key];
  //     final lset = Set.from(_listenTo);

  //     final cyclicCheck = effectTrigger._cyclicDetect[key]!.intersection(
  //       Set.from(_allowedMutate),
  //     );

  //     if (cyclicCheck.length > 0) {
  //       throw StateError(
  //         "Cyclic update detected: The effect for '$key' triggered a mutation on '$cyclicCheck', causing an infinite loop.",
  //       );
  //     }
  //     effectTrigger.listenTo(key, this);
  //   }
  // }

  TriggerEffect([T? etrig = null]) {
    if (etrig != null) {
      _trigger = etrig;
    }
    _listenTo = listenTo().toList();
    _allowedMutate = allowedMutate().toSet();

    // --- ส่วนที่ปรับปรุงใหม่ ---

    // 1. รวบรวม "ต้นเหตุ" ทั้งหมด (ทั้งทางตรงจาก _listenTo และทางอ้อมจากสิ่งที่บรรพบุรุษฟังมา)
    // 2. ใน Constructor ตอนสะสม
    final allAncestors = <String>{};
    for (final lKey in _listenTo) {
      allAncestors.add(lKey);
      allAncestors.addAll(
        _getDeepAncestors(lKey, effectTrigger._impactMap, {}),
      );
    }

    // 2. ตรวจสอบว่า "ผลลัพธ์" ที่เราจะแก้มันไปทับซ้อนกับ "ต้นเหตุ" หรือไม่
    for (final mKey in _allowedMutate) {
      if (allAncestors.contains(mKey)) {
        throw StateError(
          "Cyclic update detected: The effect mutates '$mKey', but '$mKey' is already a root cause for this effect (directly or indirectly).",
        );
      }

      // 3. บันทึกความสัมพันธ์ลงใน Trigger เพื่อให้ Effect ตัวถัดไปที่จะมาฟัง mKey รู้จักต้นตอ
      // บันทึกแค่ทางตรง (Direct Link) เพื่อให้ Graph ข้อมูลไม่อึดอัด
      if (!effectTrigger._impactMap.containsKey(mKey)) {
        effectTrigger._impactMap[mKey] = {};
      }
      effectTrigger._impactMap[mKey]!.addAll(
        _listenTo,
      ); // ใส่แค่ _listenTo ไม่ต้อง allAncestors
    }

    // 4. เริ่มฟังค่า (Listen) ตามปกติ
    for (final lKey in _listenTo) {
      effectTrigger.listenTo(lKey, this);
    }
  }

  void onTrigger();

  void update() {
    onTrigger();
  }
}
