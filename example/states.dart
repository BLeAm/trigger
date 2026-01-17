import 'package:trigger/trigger.dart';
import 'package:trigger/trigger_widgets.dart';
part 'states.g.dart';

extension MyTriggerMeth on MyTrigger {
  void addCounter() => counter += 1;
}
