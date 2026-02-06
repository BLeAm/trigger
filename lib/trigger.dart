abstract interface class Updateable {
  void update();
}

abstract base class Trigger {
  static final Set<Trigger> _instances = {};
  static final Set<Type> _registeredTypes = {};

  static T of<T extends Trigger>() {
    for (var instance in _instances) {
      if (instance is T) {
        return instance;
      }
    }
    throw Exception('No instance of type $T found.');
  }

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

  final Map<String, dynamic> _values = {};
  final Map<String, Set<Updateable>> _listenMap = {};

  void escapeHatch(
    void Function(
      Map<String, dynamic> valueMap,
      Map<String, Set<Updateable>> listenMap,
    )
    func,
  ) {
    func(_values, _listenMap);
  }

  void setValue(String key, dynamic value) {
    _values[key] = value;
    if (_listenMap.containsKey(key)) {
      for (var state in _listenMap[key]!) {
        state.update();
      }
    }
  }

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

  dynamic getValue(String key) {
    return _values[key];
  }

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

void triggerEffect<T extends Trigger>({
  required Iterable<String> listenTo,
  required void Function(T) update,
}) {
  final trigger = Trigger.of<T>();
  for (var key in listenTo) {
    trigger.listenTo(key, _EffectUpdatable(() => update(trigger)));
  }
}

class _EffectUpdatable implements Updateable {
  final void Function() callback;

  _EffectUpdatable(this.callback);

  @override
  void update() {
    callback();
  }
}

abstract base class TriggerEffect<T extends Trigger> implements Updateable {
  T get trigger;
  Iterable<String> get listenTo;

  TriggerEffect() {
    for (final key in listenTo) {
      trigger.listenTo(key, this);
    }
  }

  void dispose() {
    trigger.stopListeningAll(this);
  }
}

class TriggerGen {
  final String name;

  const TriggerGen(this.name);
}
