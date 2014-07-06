/**
 * Execution of a task in the spawned isolate.
 */
library dake.exec;

import 'dart:async';
import 'dart:isolate';

import 'package:args/args.dart';

/**
 * Exception thrown if anything went wrong during the execution of a task.
 */
class _DakeException implements Exception {
    final String message;
    const _DakeException(this.message);
    String toString() => "FormatException: $message";
}

/**
 * Creates the request Map that contains the information for a given task execution.
 *
 * As the execution of the task will occur in the DakeTasks' isolate, we need to send the execution information
 * as a simple map.
 *
 * This creates the map from the command line parsed result, casting the string command line arguments to the needed type for execution.
 *
 * This also checks that all required arguments are provided.
 */
Map _makeRequest(ArgResults commandRes, Map task) {
    var req = {
        'task': commandRes.name,
        'positional': [],
        'named': {}
    };
    var args = new List.from(commandRes.rest);
    task['params'].forEach((Map param) {
        if (param['req'] == 'req' && args.isEmpty) {
            throw new _DakeException("Missing required argument ${param['name']}");
        }
        if (!args.isEmpty) {
            String arg = args.removeAt(0);
            req['positional'].add(_argToType(param['type'], arg));
        }
    });
    task['options'].where((opt) => commandRes[opt['name']] != null).forEach((opt) {
        req['named'][opt['name']] = commandRes[opt['name']];
    });
    return req;
}

/**
 * Casts a string to the needed type.
 */
dynamic _argToType(String type, String arg) {
    switch (type) {
        case 'string': return arg; break ;
        case 'int':    return int.parse(arg); break ;
        case 'double': return double.parse(arg); break ;
        case 'num':    return num.parse(arg); break ;
        case 'bool':   return (arg == 'true' || arg == 'yes' || arg == 'y' || arg == '1'); break ;
        default:
            throw new _DakeException("Unknown type $type");
    }
}

/**
 * Asks the DakeTasks' isolate to run the given task with the given command line arguments.
 *
 * Returns a future that is completed when the task has finished runing.
 */
Future execTask(SendPort sendPort, Stream receiveStream, ArgResults commandRes, Map task) {
    try {
        sendPort.send(_makeRequest(commandRes, task));
        Completer _completer = new Completer();
        receiveStream.first.then((bool ret) {
            if (ret)
                _completer.complete();
            else
                _completer.completeError(null);
        });
        return _completer.future;
    }
    on _DakeException catch (e) {
        print("In ${commandRes.name}:");
        print(e.message);
        return new Future.error(null);
    }
}