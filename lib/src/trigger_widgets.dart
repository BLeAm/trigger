part of '../trigger.dart';

class TriggerWidget<T extends Trigger> extends StatefulWidget {
  final T? _trigger;
  final Widget Function(T trigger, BuildContext context) _build;
  final List<String> _listenTo;
  final void Function()? _initState;
  final void Function()? _dispose;
  final void Function()? _activate;
  final void Function()? _deactivate;
  final void Function()? _didChangeDependencies;

  const TriggerWidget({
    Key? key,
    T? trigger,
    required List<String> listenTo,
    void Function()? initState,
    void Function()? dispose,
    void Function()? activate,
    void Function()? deactivate,
    void Function()? didChangeDependencies,
    required Widget Function(T trigger, BuildContext context) build,
  })  : _trigger = trigger,
        _build = build,
        _listenTo = listenTo,
        _initState = initState,
        _dispose = dispose,
        _activate = activate,
        _deactivate = deactivate,
        _didChangeDependencies = didChangeDependencies,
        super(key: key);

  UnmodifiableListView<String> get listenTo =>
      UnmodifiableListView<String>(_listenTo);

  @override
  State<TriggerWidget<T>> createState() => _TriggerState<T>();
}

class _TriggerState<T extends Trigger>
    extends TriggerState<T, TriggerWidget<T>> {
  T? _trigger;

  @override
  List<String> get listenTo => widget._listenTo;
  @override
  T get trigger => _trigger ??= widget._trigger ?? Trigger.of<T>();

  @override
  void initState() {
    var func = widget._initState;
    if (func != null) {
      func();
    }
    super.initState();
  }

  @override
  void activate() {
    var func = widget._activate;
    if (func != null) {
      func();
    }
    super.activate();
  }

  @override
  void deactivate() {
    var func = widget._deactivate;
    if (func != null) {
      func();
    }
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    var func = widget._didChangeDependencies;
    if (func != null) {
      func();
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    trigger._unRegister(this);
    var func = widget._dispose;
    if (func != null) {
      func();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._build(trigger, context);

  @override
  void update() {
    setState(() {});
  }
}
