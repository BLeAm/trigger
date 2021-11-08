part of '../trigger.dart';

typedef _BuilderFunc<T> = Widget Function(
    _SelfTrigger<T> self, BuildContext context);

class _SelfTrigger<T> {
  late final _SelfTriggerWidgetState<T> _state;
  T get data => _state.data;

  void update(T data) {
    _state.update(data);
  }
}

class SelfTriggerWidget<T> extends StatefulWidget {
  final T _initData;
  final _BuilderFunc<T> _builder;
  final _SelfTrigger<T> _selfTrigger;

  factory SelfTriggerWidget(
      {Key? key, required T initData, required _BuilderFunc<T> builder}) {
    return SelfTriggerWidget._create(
      key: key ?? UniqueKey(),
      initData: initData,
      selfTrigger: _SelfTrigger<T>(),
      builder: builder,
    );
  }

  const SelfTriggerWidget._create(
      {Key? key,
      required T initData,
      required _SelfTrigger<T> selfTrigger,
      required _BuilderFunc<T> builder})
      : _builder = builder,
        _initData = initData,
        _selfTrigger = selfTrigger,
        super(key: key);

  T get data => _selfTrigger.data;
  void update(T data) => _selfTrigger.update(data);

  @override
  _SelfTriggerWidgetState<T> createState() => _SelfTriggerWidgetState<T>();
}

class _SelfTriggerWidgetState<T> extends State<SelfTriggerWidget<T>> {
  late T data;

  @override
  void initState() {
    widget._selfTrigger._state = this;
    data = widget._initData;
    super.initState();
  }

  void update(T newData) {
    setState(() {
      data = newData;
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget._builder(widget._selfTrigger, context);
}
