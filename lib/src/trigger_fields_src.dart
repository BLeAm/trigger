part of '../trigger.dart';

abstract class TriggerFields<T extends Trigger> {
  final Set<int> _list = {};
  bool _isUsed = false;

  List<int> getList() {
    if (_isUsed) {
      throw StateError('TriggerFields can only be executed once.');
    }
    _isUsed = true;
    return _list.toList();
  }

  void addField(int index) => _list.add(index);
}
