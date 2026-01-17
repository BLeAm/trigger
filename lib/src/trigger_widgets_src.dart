import 'dart:collection';
import 'dart:async';
import 'package:flutter/material.dart';
import '../trigger.dart';

part 'selftrigger_widget_src.dart';
part 'trigger_field_src.dart';

mixin TriggerStateMixin<T extends StatefulWidget, U extends Trigger> on State<T>
    implements Updateable {
  U? _trigger;
  U get trigger => _trigger!;
  Iterable<String> get listenTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<TriggerScope<U>>();
    final newTrigger = scope?.trigger ?? Trigger.of<U>();
    if (_trigger != newTrigger) {
      _trigger = newTrigger;
      for (final key in listenTo) {
        trigger.listenTo(key, this);
      }
    }
  }

  @override
  void dispose() {
    trigger.stopListeningAll(this);
    super.dispose();
  }

  void update() {
    if (mounted) setState(() {});
  }
}

class TriggerScope<U extends Trigger> extends InheritedWidget {
  const TriggerScope({super.key, required this.trigger, required super.child});

  final U trigger;

  static U of<U extends Trigger>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TriggerScope<U>>();
    if (scope == null) {
      throw Exception('No TriggerScope of type $U found in context.');
    }
    return scope.trigger;
  }

  @override
  bool updateShouldNotify(covariant TriggerScope<U> oldWidget) {
    return oldWidget.trigger != trigger;
  }
}

class TriggerWidget<U extends Trigger> extends StatefulWidget {
  const TriggerWidget({
    super.key,
    required this.listenTo,
    required this.builder,
  });

  final Iterable<String> listenTo;
  final Widget Function(BuildContext context, U trigger) builder;

  @override
  State<TriggerWidget<U>> createState() => _TriggerWidgetState<U>();
}

class _TriggerWidgetState<U extends Trigger> extends State<TriggerWidget<U>>
    with TriggerStateMixin<TriggerWidget<U>, U> {
  @override
  Widget build(BuildContext context) => widget.builder(context, trigger);

  @override
  Iterable<String> get listenTo => widget.listenTo;
}
