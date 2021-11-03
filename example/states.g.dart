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
}

class MyTriggerField extends TriggerField {
  MyTriggerField get counter {
    addField('counter');
    return this;
  }
}
