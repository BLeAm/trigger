import 'dart:collection';
import 'dart:async';
import 'package:flutter/material.dart';

part 'src/trigger_field.dart';
part 'src/trigger_widgets.dart';
part 'src/selftrigger_widget.dart';
part 'src/operation.dart';

abstract class Trigger {
  static final List<Trigger> _triggers = [];
  // static List<Trigger> get triggers => _triggers;
  static T of<T extends Trigger>() {
    T res;
    try {
      res = _triggers.firstWhere((element) => element is T) as T;
    } on StateError {
      throw TriggerError(
          'Trigger<$T>.of error: No Initialized $T can be found or provided!');
    } catch (e) {
      rethrow;
    }
    return res;
  }

  Trigger() {
    _triggers.add(this);
  }

  final _valueTable = <String, Object>{};
  final _stateTable = <String, Set<TriggerState>>{};

  void _register(List<String> keys, TriggerState state) {
    for (var key in keys) {
      if (!_stateTable.containsKey(key)) {
        _stateTable[key] = <TriggerState>{};
      }
      _stateTable[key]?.add(state);
    }
  }

  void _unRegister(TriggerState state) {
    for (var states in _stateTable.values) {
      states.remove(state);
    }
  }

  ///Check if the key is existed in _stateTable, makes an empty list of _TriggerState if it's not.
  void _ensureStateKey(String key) {
    if (!_stateTable.containsKey(key)) _stateTable[key] = <TriggerState>{};
  }

  ///Get the according value.
  dynamic getValue(String key) => _valueTable[key];

  ///To set the according value and update the states which listen to this value.
  void setValue(String key, Object val) {
    _valueTable[key] = val;
    _ensureStateKey(key);
    for (var state in _stateTable[key]!) {
      state.update();
    }
  }

  ///To set the according values and update the states which listen to thiese values.
  void setMultiValue(Map<String, dynamic> maps) {
    Set<TriggerState> _statesToUpdate = {};
    for (var key in maps.keys) {
      _ensureStateKey(key);
      _valueTable[key] = maps[key];
      _statesToUpdate.addAll([...?_stateTable[key]]);
    }
    for (var state in _statesToUpdate) {
      state.update();
    }
  }
}

class TriggerError implements Exception {
  String? cause;
  late final String triggers;

  TriggerError([this.cause]) {
    triggers = Trigger._triggers.toString();
  }

  @override
  String toString() => cause ?? '';
}

abstract class TriggerState<T extends Trigger, STF extends StatefulWidget>
    extends State<STF> {
  List<String> get listenTo;
  T get trigger => Trigger.of<T>();
  void update() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    trigger._register(listenTo, this);
  }
}
