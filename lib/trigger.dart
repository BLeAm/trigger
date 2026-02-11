import 'dart:collection';
import 'package:meta/meta.dart';

export 'src/annotations.dart';

part 'src/trigger_effect_src.dart';
part 'src/trigger_fields_src.dart';

abstract interface class Updateable {
  void update();
}

abstract base class Trigger {
  static final Set<Trigger> _instances = {};
  static final Set<Type> _registeredTypes = {};

  static void remove(Type T) {
    _instances.removeWhere((e) => e.runtimeType == T);
    _registeredTypes.removeWhere((e) => e == T);
  }

  static T of<T extends Trigger>() {
    for (var instance in _instances) {
      if (instance is T) {
        return instance;
      }
    }
    throw Exception('No instance of type $T found.');
  }

  final Map<String, Set<String>> _impactMap = {};
  final Map<String, Object?> _values = {};
  final Map<String, Set<Updateable>> _listenMap = {};

  //This register flag is to register this trigger as singleton or not.
  Trigger([bool register = true]) {
    final onlyInstance = !_registeredTypes.contains(runtimeType);
    if (register) {
      if (!onlyInstance) {
        throw StateError('Trigger $runtimeType already registered');
      }
      _instances.add(this);
      _registeredTypes.add(runtimeType);
    }
  }

  @protected
  void setValue(String key, dynamic value) {
    _values[key] = value;
    if (_listenMap.containsKey(key)) {
      for (var state in _listenMap[key]!) {
        state.update();
      }
    }
  }

  @protected
  void setMultiValues(Map<String, dynamic> newValues) {
    Set<Updateable> statesToUpdate = {};
    newValues.forEach((key, value) {
      _values[key] = value;
      statesToUpdate.addAll(_listenMap[key] ?? {});
    });
    for (var state in statesToUpdate) {
      state.update();
    }
  }

  @protected
  Object? getValue(String key) {
    return _values[key];
  }

  @protected
  void listenTo(String key, Updateable state) {
    if (!_listenMap.containsKey(key)) {
      _listenMap[key] = {};
    }
    _listenMap[key]!.add(state);
  }

  void stopListeningAll(Updateable state) {
    for (var states in _listenMap.values) {
      states.remove(state);
    }
  }
}
