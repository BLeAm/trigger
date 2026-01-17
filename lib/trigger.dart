abstract interface class Updateable {
  void update();
}

abstract base class Trigger {
  static final Set<Trigger> _instances = {};

  static T of<T extends Trigger>() {
    for (var instance in _instances) {
      if (instance is T) {
        return instance;
      }
    }
    throw Exception('No instance of type $T found.');
  }

  Trigger() {
    _instances.add(this);
  }

  final Map<String, dynamic> _values = {};
  final Map<String, Set<Updateable>> _listenMap = {};

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
