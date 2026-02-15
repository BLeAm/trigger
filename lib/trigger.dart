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

  static T of<T extends Trigger>() {
    final instance = _instances[T];
    if (instance != null) return instance as T;
    throw Exception('No instance of type $T found.');
  }

  final Map<String, Set<String>> _impactMap = {};
  final Map<String, Object?> _values = {};
  final Map<String, Set<Updateable>> _listenMap = {};
  final Map<Updateable, Set<String>> _reverseListenMap =
      LinkedHashMap.identity();

  //This register flag is to register this trigger as singleton or not.
  Trigger([bool register = true]) {
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
    final listeners = _listenMap[key];
    if (listeners != null) {
      // ใช้ for-in แทน .forEach เพื่อลด overhead ของ closure
      for (final state in listeners) {
        state.update();
      }
    }
  }

  @protected
  void setMultiValues(Map<String, dynamic> newValues) {
    final Set<Updateable> statesToUpdate = LinkedHashSet.identity();

    // 2. ใช้ for-in ประสิทธิภาพดีกว่า .forEach
    for (final entry in newValues.entries) {
      final key = entry.key;
      _values[key] = entry.value;

      final listeners = _listenMap[key];
      if (listeners != null) {
        statesToUpdate.addAll(listeners);
      }
    }

    for (final state in statesToUpdate) {
      state.update();
    }
  }

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

    // เรียงลำดับ Key เพื่อให้หาได้ง่าย
    final sortedKeys = _impactMap.keys.toList()..sort();

    for (final mKey in sortedKeys) {
      final listeners = _impactMap[mKey]!;
      final sortedListeners = listeners.toList()..sort();

      // แสดงผลในรูปแบบ: MutateKey -> [ListenKey1, ListenKey2, ...]
      // ความหมายคือ: ถ้า MutateKey เปลี่ยน จะกระทบไปยังกลุ่มที่ฟัง ListenKeys เหล่านี้
      print('  $mKey ⟸ [${sortedListeners.join(', ')}]');
    }
    print('==============================================');
  }

  void dispose() {
    _values.clear();
    _listenMap.clear();
    _reverseListenMap.clear();
    _impactMap.clear();

    if (_instances[runtimeType] == this) {
      _instances.remove(runtimeType);
    }
  }
}
