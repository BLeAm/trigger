import 'package:trigger/trigger.dart';
part 'states.g.dart';

var f = MyTriggerField();

extension MyTriggerMeth on MyTrigger {
  void addCounter() => counter += 1;
}
