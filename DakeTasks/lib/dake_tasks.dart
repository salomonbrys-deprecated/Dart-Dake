/**
 * Features needed to propose command line tasks through Dake.
 *
 * Please refer to [the documentation](http://pub.dartlang.org/packages/dake_tasks) to understand how to use this package.
 */
library dake_tasks;

import 'dart:io';
import 'dart:mirrors';
import 'dart:isolate';
import 'dart:async';

part 'src/annotations.dart';
part 'src/control.dart';

/**
 * Main function for DakeTasks.dart.
 *
 * In your DakeTasks.dart, you should have a main that is only:
 *
 *     main(List<String> args, SendPort port) => DakeMain([Cls1, Cls2], args, port);
 *
 * Where the first argument is a list of classes that contains your tasks.
 *
 * While it is **NOT** recommended to have a DakeTasks.dart file that can be executed on its own, you can do it
 * and use DakeMain only if DakeTasks.dart was launched through dake:
 *
 *     main(List<String> args, SendPort port) {
 *         if (isDake(args, port))
 *             DakeMain([Cls1, Cls2], args, port);
 *         else
 *             MyOwnMain(args, port);
 */
void DakeMain(List<Type> taskClasses, List<String> args, SendPort sendPort) {
    if (!isDake(args, sendPort)) { // Next arguments are reserved for future usage
        throw new Exception("DakeTasks file must be used through dake and not directly as a command line dart app.");
    }

    args.removeAt(0);

    var options = new Map.fromIterable(args.where((e) => e is String), key: (e) => e.split(':')[0], value: (e) => e.split(':')[1]);

    _Control ctrl = new _Control(taskClasses);

    var receivePort = new ReceivePort();

    sendPort.send({'sendPort': receivePort.sendPort, 'tasks': ctrl.description});

    receivePort.listen((Map taskArgs) {
        if (taskArgs.isEmpty) {
            receivePort.close();
            return (dakeRepo as _DakeRepo)._close();
        }

        ctrl.call(taskArgs)
            .then((_) => sendPort.send(true), onError: (err, st) {
                var errorType = MirrorSystem.getName(reflect(err).type.simpleName);
                if (!options.containsKey('NoError') || options['NoError'] != errorType) {
                    print("!!! " + errorType + " running " + taskArgs['task'] + " !!!");
                    print("");
                    print(err.toString());
                    print("");
                    print(st.toString());
                }
                sendPort.send(false);
            })
        ;
    });
}

/**
 * Returns whether or not this main was called for Dake.
 *
 * Please use it ONLY if:
 *
 *  1. You know what you are doing.
 *  2. You absolutely have to.
 */
bool isDake(List<String> args, SendPort sendPort) {
    return sendPort != null && args != null && !args.isEmpty && args[0] == "__DAKE__";
}

/**
 * Singleton repository.
 *
 * For each type, has one instance of it. If it doesn't, it will instantiate it with the no-arg unnamed default constructor.
 *
 * This itself is a singleton and should only be used through the [dakeRepo] static variable
 */
abstract class DakeRepo {
    /**
     * Get the singleton object of the given type.
     */
    dynamic operator [] (Type type);
}

/**
 * Interface that the task class may implement to be called on program's end.
 *
 * If a task class implements this interface, it shall be called once all tasks have successfully finished.
 */
abstract class DakeClosable {
    void close();
}

/**
 * Singleton implementation of [DakeRepo]
 */
class _DakeRepo implements DakeRepo {

    Map<Type, dynamic> _objects = new Map();

    operator [] (Type type) {
        if (!_objects.containsKey(type))
            _objects[type] = reflectClass(type).newInstance(new Symbol(""), []).reflectee;
        return _objects[type];
    }

    _close() {
        _objects.values.where((o) => o is DakeClosable).forEach((o) => o.close());
        _objects.clear();
    }

}

/**
 * Singleton repository usable for inter-class task dependencies.
 *
 * If you have an inter-class task dependency (a task in a class that depends on another task in another class),
 * you can use this object to access the instance of the other class.
 *
 * class TasksClassA {
 *     @Task("A composite task")
 *     Future compositeTask() {
 *         return dakeRepo[TasksClassB].simpleTask().then((_) => _doSomething());
 *     }
 */
DakeRepo dakeRepo = new _DakeRepo();
