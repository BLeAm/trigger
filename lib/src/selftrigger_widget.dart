part of '../trigger.dart';

class _ReachableValueStream<T> {
  T _data;
  final _strmCtrl = StreamController<T>();

  Stream<T> get _stream => _strmCtrl.stream;

  _ReachableValueStream({required T initData}) : _data = initData;

  void _update(T val) {
    _data = val;
    _strmCtrl.sink.add(val);
  }
}

class SelfTriggerWidget<T> extends StatefulWidget {
  final _ReachableValueStream<T> _rvStream;
  final Widget Function(T? data, BuildContext context) _builder;
  final String name;

  T get data => _rvStream._data;

  static final _widgetBank = <String, SelfTriggerWidget>{};
  static SelfTriggerWidget<T>? find<T>(String name) {
    final widget = _widgetBank[name];
    if ((widget != null) & (widget is SelfTriggerWidget<T>)) {
      return widget as SelfTriggerWidget<T>;
    }
    return null;
  }

  factory SelfTriggerWidget({
    Key? key,
    String name = '',
    required T initData,
    required Widget Function(T? data, BuildContext context) builder,
  }) {
    final widget = SelfTriggerWidget._create(
      key: key,
      name: name,
      initData: initData,
      builder: builder,
      rvStream: _ReachableValueStream<T>(initData: initData),
    );

    if (widget.name.isNotEmpty) _widgetBank[widget.name] = widget;

    return widget;
  }

  const SelfTriggerWidget._create({
    Key? key,
    required this.name,
    required T initData,
    required Widget Function(T? data, BuildContext context) builder,
    required rvStream,
  })  : _rvStream = rvStream,
        _builder = builder,
        super(key: key);

  void Function(T val) get update => _rvStream._update;

  @override
  State<SelfTriggerWidget<T>> createState() => _SelfTriggerWidgetState<T>();
}

class _SelfTriggerWidgetState<T> extends State<SelfTriggerWidget<T>> {
  @override
  void dispose() {
    SelfTriggerWidget._widgetBank
        .removeWhere((key, value) => key == widget.name);
    // print('SelfTriggerWidget <${widget.name}> is disposed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        initialData: widget._rvStream._data,
        stream: widget._rvStream._stream,
        builder: (context, snapshot) => widget._builder(snapshot.data, context),
      );
}
