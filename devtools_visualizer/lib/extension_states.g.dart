// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'extension_states.dart';

// **************************************************************************
// TriggerGenerator
// **************************************************************************

typedef _ExtensionStatesEffectCreator = void Function(ExtensionStates t);

final class ExtensionStates extends Trigger {
  static const int _idxTriggers = 0;
  static const int _idxPreviousValues = 1;
  static const int _idxSearchQuery = 2;
  static const int _idxShowOnlyChanges = 3;

  static const int _fieldCount = 4;

  static ExtensionStates? _instance;

  static final List<String> _fieldNamesList = [
    'triggers',
    'previousValues',
    'searchQuery',
    'showOnlyChanges',
  ];

  static ExtensionStatesFields get fields => ExtensionStatesFields();

  bool _fxAttached = false;

  ExtensionStates._internal({bool register = true, UpdateScheduler? scheduler})
    : super(
        fieldCount: _fieldCount,
        fieldNames: _fieldNamesList,
        register: register,
        scheduler: scheduler,
      ) {
    if (register) {
      _fxAttached = true;
    }
    triggers = [];
    previousValues = {};
    searchQuery = '';
    showOnlyChanges = true;
  }

  //this will be used to spawn a new ExtensionStates instance that is not singleton.
  factory ExtensionStates.spawn({UpdateScheduler? scheduler}) =>
      ExtensionStates._internal(register: false, scheduler: scheduler);
  factory ExtensionStates({UpdateScheduler? scheduler}) {
    _instance ??= ExtensionStates._internal(scheduler: scheduler);
    return _instance!;
  }

  //Getter/Setter with performance of O(1)
  List<dynamic> get triggers =>
      UnmodifiableListView(getValue(_idxTriggers) as List<dynamic>);
  set triggers(List<dynamic> val) => setValue(_idxTriggers, val);
  Map<String, List<dynamic>> get previousValues => UnmodifiableMapView(
    getValue(_idxPreviousValues) as Map<String, List<dynamic>>,
  );
  set previousValues(Map<String, List<dynamic>> val) =>
      setValue(_idxPreviousValues, val);
  String get searchQuery => getValue(_idxSearchQuery) as String;
  set searchQuery(String val) => setValue(_idxSearchQuery, val);
  bool get showOnlyChanges => getValue(_idxShowOnlyChanges) as bool;
  set showOnlyChanges(bool val) => setValue(_idxShowOnlyChanges, val);

  // ignore: library_private_types_in_public_api
  void multiSet(void Function(_ExtensionStatesMultiSetter setter) func) {
    final setter = _ExtensionStatesMultiSetter();
    func(setter);
    setMultiValues(setter._map);
  }

  /// Attaches all master effects declared in @TriggerGen(fx: [...])
  ///
  /// - Must be called before any listeners are added
  /// - Can be called only once per instance
  /// - If no effects are declared → acts as no-op and locks further calls
  void attachMasterFx() {
    if (_fxAttached) {
      throw StateError(
        "Multiple attachment attempts are not allowed. This process is restricted to a single occurrence.",
      );
    }
    if (hasListeners()) {
      throw StateError(
        "Cannot attach master effects after listeners have been registered. "
        "Attach effects before any listening occurs.",
      );
    }

    _fxAttached = true;
  }

  // ignore: library_private_types_in_public_api
  void attachFx(List<_ExtensionStatesEffectCreator> fxs) {
    if (_fxAttached) {
      throw StateError(
        "Multiple attachment attempts are not allowed. This process is restricted to a single occurrence.",
      );
    }
    if (hasListeners()) {
      throw StateError(
        "Cannot attach master effects after listeners have been registered. "
        "Attach effects before any listening occurs.",
      );
    }
    for (var fx in fxs) {
      fx(this);
    }
    _fxAttached = true;
  }
}

final class ExtensionStatesFields extends TriggerFields<ExtensionStates> {
  ExtensionStatesFields get triggers {
    addField(ExtensionStates._idxTriggers);
    return this;
  }

  ExtensionStatesFields get previousValues {
    addField(ExtensionStates._idxPreviousValues);
    return this;
  }

  ExtensionStatesFields get searchQuery {
    addField(ExtensionStates._idxSearchQuery);
    return this;
  }

  ExtensionStatesFields get showOnlyChanges {
    addField(ExtensionStates._idxShowOnlyChanges);
    return this;
  }
}

class _ExtensionStatesMultiSetter {
  final _map = <int, dynamic>{};
  set triggers(List<dynamic> val) => _map[ExtensionStates._idxTriggers] = val;
  set previousValues(Map<String, List<dynamic>> val) =>
      _map[ExtensionStates._idxPreviousValues] = val;
  set searchQuery(String val) => _map[ExtensionStates._idxSearchQuery] = val;
  set showOnlyChanges(bool val) =>
      _map[ExtensionStates._idxShowOnlyChanges] = val;
}

abstract base class ExtensionStatesEffect
    extends TriggerEffect<ExtensionStates> {
  ExtensionStatesEffect(super.trigger);
  List<dynamic> get triggers => trigger.triggers;
  set triggers(List<dynamic> val) {
    checkAllow(ExtensionStates._idxTriggers);
    trigger.triggers = val;
  }

  Map<String, List<dynamic>> get previousValues => trigger.previousValues;
  set previousValues(Map<String, List<dynamic>> val) {
    checkAllow(ExtensionStates._idxPreviousValues);
    trigger.previousValues = val;
  }

  String get searchQuery => trigger.searchQuery;
  set searchQuery(String val) {
    checkAllow(ExtensionStates._idxSearchQuery);
    trigger.searchQuery = val;
  }

  bool get showOnlyChanges => trigger.showOnlyChanges;
  set showOnlyChanges(bool val) {
    checkAllow(ExtensionStates._idxShowOnlyChanges);
    trigger.showOnlyChanges = val;
  }

  // ignore: library_private_types_in_public_api
  void multiSet(Function(_ExtensionStatesMultiSetter setter) func) {
    final setter = _ExtensionStatesMultiSetter();
    func(setter);
    for (final key in setter._map.keys) {
      checkAllow(key);
    }
    // ignore: invalid_use_of_protected_member
    trigger.setMultiValues(setter._map);
  }
}
