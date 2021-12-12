part of 'states.dart';

class MyTrigger extends Trigger {
  static MyTrigger? _instance;

  MyTrigger._create() {
    counter = 0;
  }

  factory MyTrigger() {
    return _instance ??= MyTrigger._create();
  }
  int get counter => getValue('counter')!;
  set counter(int val) => setValue('counter', val);

  void multiSet(void Function(_MyTriggerMultiSetter setter) func) {
    final setter = _MyTriggerMultiSetter();
    func(setter);
    setMultiValue(setter._map);
  }
}

class MyTriggerField extends TriggerField {
  MyTriggerField get counter {
    addField('counter');
    return this;
  }
}

class _MyTriggerMultiSetter {
  final _map = <String, dynamic>{};
  set counter(int val) => _map["counter"] = val;
}
