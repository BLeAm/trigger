import 'dart:collection';
import 'package:meta/meta.dart';

export 'src/annotations.dart';

part 'src/trigger_effect_src.dart';
part 'src/trigger_fields_src.dart';

abstract interface class Updateable {
  void update();
}

abstract base class Trigger {
  // 1. เปลี่ยนเป็น Map เพื่อให้ of<T>() เป็น O(1)
  static final Map<Type, Trigger> _instances = {};

  // 2. ระบบ Batch Update: ถังพักคิวและ Flag แจ้งเตือน Scheduler
  // ใช้ Static เพื่อให้ทุก Trigger Share คิวการอัปเดต UI ร่วมกันในเฟรมเดียว
  static final Set<Updateable> _updateQueue = LinkedHashSet.identity();
  static bool _isBatchingScheduled = false;

  static T of<T extends Trigger>() {
    final instance = _instances[T];
    if (instance != null) return instance as T;
    throw Exception('No instance of type $T found.');
  }

  static void Function(Set<Updateable> updatedStates)? onBatchUpdate;

  final Map<String, Set<String>> _impactMap = {};
  final Map<String, Object?> _values = {};
  final Map<String, Set<Updateable>> _listenMap = {};
  final Map<Updateable, Set<String>> _reverseListenMap =
      LinkedHashMap.identity();

  // เพิ่ม flag เพื่อบอกว่าเป็น Singleton หรือไม่
  final bool isSingleton;

  //This register flag is to register this trigger as singleton or not.
  Trigger([bool register = true]) : isSingleton = register {
    if (register) {
      if (_instances.containsKey(runtimeType)) {
        throw StateError('Trigger $runtimeType already registered');
      }
      _instances[runtimeType] = this;
    }
  }

  /// ฟังก์ชันภายในสำหรับส่ง Listener เข้าคิวรอประมวลผลท้าย Microtask
  void _enqueueUpdates(Iterable<Updateable>? listeners) {
    if (listeners == null || listeners.isEmpty) return;

    _updateQueue.addAll(listeners);

    if (!_isBatchingScheduled) {
      _isBatchingScheduled = true;
      // รวบตึงการ Rebuild ไปไว้ที่ท้าย Microtask เพื่อประหยัด CPU
      Future.microtask(_processQueue);
    }
  }

  /// ทำการระเบิดคิว สั่ง update() ทุกคนที่อยู่ในคิวแค่ครั้งเดียว
  static void _processQueue() {
    // ถ้ามีคนเสียบปลั๊ก Logger ไว้ ก็ส่งข้อมูลไปบอก
    if (onBatchUpdate != null) {
      // ส่ง Copy ของคิวไป (ใช้ .toSet()) เพื่อความปลอดภัย
      onBatchUpdate!(Set.from(_updateQueue));
    }
    for (final state in _updateQueue) {
      state.update();
    }
    _updateQueue.clear();
    _isBatchingScheduled = false;
  }

  @protected
  void setValue(String key, dynamic value) {
    _values[key] = value;
    // แทนที่จะ loop สั่ง update ทันที ให้ส่งเข้าคิวแทน
    _enqueueUpdates(_listenMap[key]);
  }

  @protected
  void setMultiValues(Map<String, dynamic> newValues) {
    for (final entry in newValues.entries) {
      _values[entry.key] = entry.value;
      _enqueueUpdates(_listenMap[entry.key]); // ใช้ helper ที่ทำไว้แล้ว
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
    // ป้องกันกรณีที่กำลังจะอัปเดตแต่ Widget ดันโดน dispose ไปก่อน
    _updateQueue.remove(state);

    final keys = _reverseListenMap.remove(state);
    if (keys != null) {
      for (final key in keys) {
        final listeners = _listenMap[key];
        if (listeners != null) {
          listeners.remove(state);
          if (listeners.isEmpty) {
            _listenMap.remove(key);
          }
        }
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
