part of '../trigger.dart';

abstract class TriggerFields<T extends Trigger> with IterableMixin<String> {
  final List<String> _list = [];

  @override
  int get length => _list.length;
  @override
  Iterator<String> get iterator {
    final res = List<String>.from(_list);
    _list.clear();
    return res.iterator;
  }

  void addField(String str) => _list.add(str);
}
