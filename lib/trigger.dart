import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:meta/meta.dart';

export 'src/annotations.dart';
export 'package:meta/meta.dart' show protected;

part 'src/trigger_effect_src.dart';
part 'src/trigger_fields_src.dart';
part 'src/scheduler_src.dart';
part 'src/trigger_inspector.dart';

abstract interface class Updateable {
  void update();
}

abstract base class Trigger {
  // 1. เปลี่ยนเป็น Map เพื่อให้ of<T>() เป็น O(1)
  static final Map<Type, Trigger> _instances = {};

  final UpdateScheduler _scheduler;
  // เพิ่ม flag เพื่อบอกว่าเป็น Singleton หรือไม่
  final bool isSingleton;
  late final List<Object?> _values;
  late final List<Set<Updateable>> _listenMap;
  final List<String> _fieldNames;

  // Dependency map: Map<MutatedIndex, Set<ListenerIndex>>
  final Map<int, Set<int>> _impactMap = {};

  final Map<Updateable, Set<int>> _reverseListenMap = LinkedHashMap.identity();

  static T of<T extends Trigger>() {
    final instance = _instances[T];
    if (instance != null) return instance as T;
    throw Exception('No instance of type $T found.');
  }

  //This register flag is to register this trigger as singleton or not.
  Trigger({
    required int fieldCount,
    required List<String> fieldNames,
    bool register = true,
    UpdateScheduler? scheduler,
  }) : _fieldNames = fieldNames,
       _scheduler = scheduler ?? defaultUpdateScheduler,
       isSingleton = register {
    _values = List<Object?>.filled(fieldCount, null);
    _listenMap = List.generate(fieldCount, (_) => LinkedHashSet.identity());

    if (register) {
      if (_instances.containsKey(runtimeType)) {
        throw StateError('Trigger $runtimeType already registered');
      }
      _instances[runtimeType] = this;
    }
  }

  @protected
  void setValue(int index, dynamic value) {
    _values[index] = value;
    // แทนที่จะ loop สั่ง update ทันที ให้ส่งเข้าคิวแทน
    _scheduler.enqueue(_listenMap[index]);
  }

  @protected
  void setMultiValues(Map<int, dynamic> newValues) {
    final allListeners = <Updateable>{};
    for (final entry in newValues.entries) {
      _values[entry.key] = entry.value;
      allListeners.addAll(_listenMap[entry.key]);
    }
    _scheduler.enqueue(allListeners);
  }

  @visibleForTesting
  @protected
  // เนื่องจาก _listenMap เป็น List ที่มีขนาดคงที่ (ไม่ว่างเปล่าแน่ๆ)
  // ควรเช็คว่าใน Set ข้างในมีคนฟังอยู่จริงๆ ไหม
  bool hasListeners() => _listenMap.any((listeners) => listeners.isNotEmpty);

  @protected
  Object? getValue(int index) => _values[index];

  void listenTo(int index, Updateable state) {
    // ใช้ LinkedHashSet.identity เพื่อความเร็วในการจัดการ Listener
    _listenMap[index].add(state);
    _reverseListenMap.putIfAbsent(state, () => {}).add(index);
  }

  void stopListeningAll(Updateable state) {
    _scheduler.cancel(state);
    // ลบออกจากคิวรออัปเดตทันทีหากถูก Dispose
    // เข้าถึงผ่าน _updateQueue ไม่ได้แล้วเพราะย้ายไปอยู่ใน Scheduler
    // แต่เราไม่กังวลเพราะ state.update() จะไม่ทำงานถ้า Widget นั้นถูกถอดออกแล้ว

    final indices = _reverseListenMap.remove(state);
    if (indices != null) {
      for (final idx in indices) {
        _listenMap[idx].remove(state);
      }
    }
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

    _values.fillRange(0, _values.length, null);
    for (var set in _listenMap) {
      set.clear();
    }
    _reverseListenMap.clear();
    _impactMap.clear();
  }
}
