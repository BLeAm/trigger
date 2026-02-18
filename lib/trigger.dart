import 'dart:async';
import 'dart:collection';
import 'package:meta/meta.dart';

export 'src/annotations.dart';

part 'src/trigger_effect_src.dart';
part 'src/trigger_fields_src.dart';
part 'src/scheduler_src.dart';

abstract interface class Updateable {
  void update();
}

abstract base class Trigger {
  // 1. เปลี่ยนเป็น Map เพื่อให้ of<T>() เป็น O(1)
  static final Map<Type, Trigger> _instances = {};

  final UpdateScheduler _scheduler;
  // เพิ่ม flag เพื่อบอกว่าเป็น Singleton หรือไม่
  final bool isSingleton;
  final Map<String, Set<String>> _impactMap = {};
  final Map<String, Object?> _values = {};
  final Map<String, Set<Updateable>> _listenMap = {};
  final Map<Updateable, Set<String>> _reverseListenMap =
      LinkedHashMap.identity();

  static T of<T extends Trigger>() {
    final instance = _instances[T];
    if (instance != null) return instance as T;
    throw Exception('No instance of type $T found.');
  }

  //This register flag is to register this trigger as singleton or not.
  Trigger({
    bool register = true,
    UpdateScheduler?
    scheduler, // รับ Scheduler จากภายนอกได้ (ถ้าไม่ส่งมาใช้ตัวกลาง)
  }) : _scheduler = scheduler ?? defaultUpdateScheduler,
       isSingleton = register {
    if (register) {
      if (_instances.containsKey(runtimeType)) {
        throw StateError('Trigger $runtimeType already registered');
      }
      _instances[runtimeType] = this;
    }
  }

  @protected
  void setValue(String key, dynamic value) {
    _values[key] = value;
    // แทนที่จะ loop สั่ง update ทันที ให้ส่งเข้าคิวแทน
    _scheduler.enqueue(_listenMap[key]);
  }

  @protected
  void setMultiValues(Map<String, dynamic> newValues) {
    for (final entry in newValues.entries) {
      _values[entry.key] = entry.value;
      _scheduler.enqueue(_listenMap[entry.key]); // ใช้ helper ที่ทำไว้แล้ว
    }
  }

  @visibleForTesting
  @protected
  bool hasListeners() => _listenMap.isNotEmpty;

  @protected
  Object? getValue(String key) {
    return _values[key];
  }

  @protected
  void listenTo(String key, Updateable state) {
    // ใช้ LinkedHashSet.identity เพื่อความเร็วในการจัดการ Listener
    _listenMap.putIfAbsent(key, () => LinkedHashSet.identity()).add(state);
    _reverseListenMap.putIfAbsent(state, () => {}).add(key);
  }

  void stopListeningAll(Updateable state) {
    _scheduler.cancel(state);
    // ลบออกจากคิวรออัปเดตทันทีหากถูก Dispose
    // เข้าถึงผ่าน _updateQueue ไม่ได้แล้วเพราะย้ายไปอยู่ใน Scheduler
    // แต่เราไม่กังวลเพราะ state.update() จะไม่ทำงานถ้า Widget นั้นถูกถอดออกแล้ว

    final keys = _reverseListenMap.remove(state);
    if (keys != null) {
      for (final key in keys) {
        _listenMap[key]?.remove(state);
      }
    }
  }

  // เพิ่มเข้าไปใน abstract base class Trigger ในไฟล์ lib/trigger.dart
  void dumpDepsGraph() {
    print('=== Trigger Impact Graph [${runtimeType}] ===');
    if (_impactMap.isEmpty) {
      print('Empty graph');
      return;
    }
    final sortedKeys = _impactMap.keys.toList()..sort();
    for (final mKey in sortedKeys) {
      final listeners = _impactMap[mKey]!;
      final sortedListeners = listeners.toList()..sort();
      print('  $mKey ⟸ [${sortedListeners.join(', ')}]');
    }
    print('==============================================');
  }

  @mustCallSuper
  void dispose() {
    // ถ้าเป็น Singleton เราอาจจะไม่ต้องการให้ dispose
    // หรือถ้าจะ dispose ต้องถอดออกจาก registry ด้วย
    if (isSingleton) {
      // สำหรับ Singleton อาจจะแค่ล้างค่าข้างใน หรือไม่ทำอะไรเลย
      // ขึ้นอยู่กับว่าคุณอยากให้ Singleton "ตาย" ได้ไหม
      // ในที่นี้ แนะนำว่าถ้าสั่ง dispose Singleton ให้เอาออกจาก Map ด้วย
      _instances.remove(runtimeType);
    }

    _values.clear();
    _listenMap.clear();
    _reverseListenMap.clear();
    _impactMap.clear();
  }
}

void logBatchUpdate(Set<Updateable> updatedStates) {
  print('🔔 [Batch Update] ${updatedStates.length} states rebuilt:');
  for (var s in updatedStates) {
    print('   -> ${s.runtimeType}');
  }
}
