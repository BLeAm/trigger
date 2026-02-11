import 'package:flutter/material.dart';
import 'states.dart';
import 'package:trigger/trigger.dart';
import 'package:trigger/trigger_widgets.dart';

void main() {
  MyTrigger();
  runApp(const MyApp());
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter>
    with TriggerStateMixin<Counter, MyTrigger> {
  @override
  TriggerFields<MyTrigger> get listenTo => MyTriggerFields().counter;

  @override
  Widget build(BuildContext context) {
    return Text('${trigger.counter}');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            TriggerWidget<MyTrigger>(
              listenTo: MyTrigger.fields.counter,
              builder: (context, trigger) => Text('${trigger.counter}'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Trigger.of<MyTrigger>().addCounter();
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
