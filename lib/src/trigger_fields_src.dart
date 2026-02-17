part of '../trigger.dart';

abstract class TriggerFields<T extends Trigger> {
  final List<String> _list = [];
  bool _isUsed = false;

  List<String> getList() {
    if (_isUsed) {
      throw StateError('TriggerFields can only be executed once.');
    }
    _isUsed = true;
    return _list;
  }

  void addField(String str) => _list.add(str);
}
