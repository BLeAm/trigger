# Trigger 

**Trigger** is a deterministic reactive state framework for Flutter.  
It enforces a **static acyclic dependency graph at initialization**, It enforces a static acyclic dependency graph at initialization — guaranteeing predictable updates, eliminating structural cycles, and simplifying data flow reasoning.

---

##  Why Trigger?
- **Deterministic by Design**  
  Trigger locks the dependency graph at init-time. No hidden structural cycles. No runtime graph mutations. Your app’s state updates are predictable by construction.

- **Cycle Detection Built-in**  
  Effects are validated with BFS cycle detection during initialization. If a circular dependency exists, Trigger throws immediately — saving you from runtime headaches and impossible-to-test scenarios.

- **Debugging Made Clear**  
  With `dumpDepsGraph()`, you can visualize the dependency graph in seconds. See which fields impact which effects, and reason about your data flow without guesswork.

- **Separation of Concerns**  
  Effects live outside the UI. Business logic and state transformations are explicit, structured, and easy to reason about.

- **Simple Mode or Structural Mode**  
  - *Simple*: Use Trigger without Effects — lightweight, no ceremony.  
  - *Structural*: Add Effects for deterministic data flow — more ceremony, but less cognitive load and easier testing.

---

## Philosophy
Trigger trades a little ceremony for **clarity and robustness**.  
It reduces structural and defensive testing overhead, eliminates defensive coding against cycles, and lowers cognitive load when reasoning about complex state flows.  

> *Trigger guarantees deterministic update order within the dependency graph by enforcing a static acyclic dependency graph at initialization.*

---

## Example

```dart
@TriggerGen("MainStates", fx: [BMIEffect])
class Decl {
  int counter = 0;
  double weight = 0;
  double hight = 0;
  double bmi = 0;
}

final class BMIEffect extends MainStatesEffect {
  BMIEffect(super.trigger);

  @override
  final listenTo = MainStates.fields.weight.hight;

  @override
  final allowedMutate = MainStates.fields.bmi;

  @override
  void onTrigger() {
    final h = hight / 100;
    bmi = weight / (h * h);
  }
}
