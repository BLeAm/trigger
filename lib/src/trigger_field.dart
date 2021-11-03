part of '../trigger.dart';

abstract class TriggerField with ListMixin<String> {
  final List<String> _list = [];
  bool _endFlag = false;

  @override
  int get length => _list.length;
  @override
  set length(int val) => _list.length = val;

  void addField(String str) {
    if (_endFlag) {
      _list.clear();
      _endFlag = false;
    }
    _list.add(str);
  }

  @override
  String operator [](int index) {
    var val = _list[index];
    if (index == length - 1) {
      _endFlag = true;
    }
    return val;
  }

  @override
  void operator []=(int index, String value) {}
}
