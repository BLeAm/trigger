part of '../trigger.dart';

typedef AsyncFunc<T> = Future<T> Function();

///Operation is a task helper which makes sure any task/operation would have only one action/effector to be excuted.
class Operation<T> {
  static final _checkPoint = <String, int>{};

  final String name;
  final FutureOr<T> Function() _operation;
  final void Function(T data) _effector;

  Operation({
    required this.name,
    required FutureOr<T> Function() operation,
    required void Function(T data) effector,
  })  : _operation = operation,
        _effector = effector {
    var _hash = DateTime.now().millisecondsSinceEpoch;
    _checkPoint[name] = _hash;

    if (_operation is AsyncFunc) {
      (_operation() as Future<T>).then((value) {
        if (Operation._checkPoint[name] == _hash) {
          _effector(value);
        }
      });
    } else {
      _effector(_operation() as T);
    }
  }
}
