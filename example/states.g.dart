// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'states.dart';

base class MyTrigger extends Trigger {
  static final MyTrigger _instance = MyTrigger._internal();
  static MyTriggerField fields() => MyTriggerField();

  MyTrigger._internal() {
    counter = 0;
  }

  //this will be used to spawn a new MyTrigger instance that is not singleton.
  factory MyTrigger.spawn() {
    return MyTrigger._internal();
  }

  factory MyTrigger() {
    return MyTrigger._instance;
  }
  int get counter => getValue('counter')!;
  set counter(int val) => setValue('counter', val);

  void multiSet(void Function(_MyTriggerMultiSetter setter) func) {
    final setter = _MyTriggerMultiSetter();
    func(setter);
    setMultiValues(setter._map);
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
