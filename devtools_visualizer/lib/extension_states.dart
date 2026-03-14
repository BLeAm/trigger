import 'dart:collection';

import 'package:trigger/trigger.dart';

part 'extension_states.g.dart';

@TriggerGen('ExtensionStates')
class ExtensionDecl {
  List<dynamic> triggers = [];

  Map<String, List<dynamic>> previousValues = {};
  String searchQuery = '';
  bool showOnlyChanges = true;
}
