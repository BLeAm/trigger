part of 'trigger_widgets_src.dart';

final class SelfTriggerWidgetController<T> {
  T _data;
  T get data => _data;
  final StreamController<T> _ctrl = StreamController<T>.broadcast();
  bool _disposed = false;
  Stream<T> get stream => _ctrl.stream;

  SelfTriggerWidgetController({required T data}) : _data = data;

  void update(T data) {
    if (_disposed) return;
    _data = data;
    _ctrl.sink.add(data);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ctrl.close();
  }
}

final class SelfTriggerRegistry {
  static final Map<Object, SelfTriggerWidgetController> _controllers = {};
  static SelfTriggerWidgetController<T> find<T>(Object key) {
    final ctrl = _controllers[key];
    if (ctrl == null) {
      throw Exception('No SelfTriggerWidgetController found for key "$key"');
    }
    return ctrl as SelfTriggerWidgetController<T>;
  }

  static bool hasKey(String key) => _controllers.containsKey(key);

  static void register<T>(
    Object key,
    SelfTriggerWidgetController<T> controller,
  ) {
    assert(
      !_controllers.containsKey(key),
      'SelfTriggerWidget key "$key" is already registered',
    );
    _controllers[key] = controller;
  }

  static void unregister(Object key) {
    _controllers.remove(key);
  }
}

class SelfTriggerWidget<T> extends StatefulWidget {
  final Object _key;
  final T _initData;
  final Widget Function(BuildContext context, T data) _builder;
  const SelfTriggerWidget({
    super.key,
    required Object skey,
    required T initData,
    required Widget Function(BuildContext context, T data) builder,
  }) : _key = skey,
       _initData = initData,
       _builder = builder;

  @override
  State<SelfTriggerWidget<T>> createState() => _SelfTriggerWidgetState<T>();
}

class _SelfTriggerWidgetState<T> extends State<SelfTriggerWidget<T>> {
  late final _stwCtrl = SelfTriggerWidgetController<T>(data: widget._initData);

  @override
  void initState() {
    super.initState();
    SelfTriggerRegistry.register(widget._key, _stwCtrl);
  }

  @override
  void dispose() {
    SelfTriggerRegistry.unregister(widget._key);
    _stwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      initialData: _stwCtrl.data,
      stream: _stwCtrl.stream,
      builder: (context, snapshot) {
        return widget._builder(context, snapshot.data as T);
      },
    );
  }
}
