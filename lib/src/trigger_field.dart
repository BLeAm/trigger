part of '../trigger.dart';

abstract class TriggerField with IterableMixin<String> {
  final List<String> _list = [];
  bool _endFlag = false;

  @override
  int get length => _list.length;
  @override
  Iterator<String> get iterator => _list.iterator;

  void addField(String str) {
    if (_endFlag) {
      _list.clear();
      _endFlag = false;
    }
    _list.add(str);
  }
}
