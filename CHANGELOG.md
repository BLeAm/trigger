# Changelog

0.1.0

- **DevTools Visualizer**: Added a dedicated visualizer for Dart DevTools to monitor state changes, rebuild statistics, and dependency graphs.
- **TriggerInspector**: Introduced a powerful debugging and monitoring tool with health reporting, real-time events, and dependency visualization.
- **Batch Updates**: Implemented an `UpdateScheduler` to batch state updates via microtasks, significantly reducing redundant rebuilds.
- **Singleton Support**: Added `Trigger.of<T>()` for O(1) access to registered singleton Trigger instances.
- **State History & Snapshots**: Added support for state snapshots and history tracking for improved debugging and potential time-travel.
- **Enhanced Hooks**: Added `addBatchHook` to allow reacting to batch update completions.
- **Performance Optimizations**: Switched to identity-based collections for faster listener and state tracking.

0.0.1+6

- Refactor TriggerFields from string field names to unique integer indices. And refactor Trigger to use the index of values List as the way to reach in values and states.  

0.0.1+5.1

- Tiny Bugfixes.

0.0.1+5

- Added static function, find, and changed the implementation of SelfTriggerWidget.

0.0.1+4

- Bugfixes.

0.0.1+3

- changed SelfTriggerWidget builder's signature.
- Operation class added.
- added TriggerState and changed _TriggerState mechanism.

0.0.1+2

- SelfTriggerWidget added.

0.0.1+1

- setMultiValue added in Trigger.

0.0.1

- The initial point of project.
