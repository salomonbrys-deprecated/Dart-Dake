
library dake.tasks;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:math';

import 'package:args/args.dart';

import 'exec.dart';
import 'completion.dart';

/**
 * Handles all command line given tasks.
 *
 * This handles the asynchronous call and queueing of each task:
 * it will run the next task only if the previous one has successfully ran.
 *
 * Returns a future that is completed once all tasks have been successfully executed.
 */
Future handleTasks(SendPort sendPort, Stream receiveStream, Map<String, Map> tasks, List<String> allArgs) {
    var parser = new ArgParser();
    _addParserTasks(parser, tasks);

    if (allArgs.isEmpty) {
        _taskUsage(tasks);
        return new Future.value();
    }

    if (allArgs[0] == "__completion__") {
        completion(tasks, int.parse(allArgs[1]) - 1, allArgs.sublist(2));
        return new Future.value();
    }

    parser.addCommand("__completion__");

    Future task = new Future.value();
    _splitTaskArgs(allArgs).forEach((args) => task = task.then((_) {
        ArgResults argResult;
        try {
            argResult = parser.parse(args);
        }
        on FormatException catch(e) {
            print(e.message);
            exit(1);
        }

        if (argResult.command == null) {
            print('Could not find a task named "${argResult.rest[0]}"');
            exit(1);
        }

        return execTask(sendPort, receiveStream, argResult.command, tasks[argResult.command.name]);
    }));
    return task;
}

/**
 * Adds the options and flags to the given parser corresponding to the given task.
 */
void _addParserTasks(ArgParser parser, Map<String, Map> tasks) {
    tasks.forEach((com, desc) {
        desc['parser'] = parser.addCommand(com, new ArgParser(allowTrailingOptions: true));
        desc['options'].forEach((o){
            if (o['type'] == 'bool')
                desc['parser'].addFlag(o['name'], help: "(${o['dispType']}) ${o.containsKey('help') ? o['help'] : ''}", defaultsTo: null, abbr: o['optAbbr']);
            else
                desc['parser'].addOption(o['name'], help: "(${o['dispType']}) ${o.containsKey('help') ? o['help'] : ''}", abbr: o['optAbbr']);
        });
    });
}

/**
 * Split the given args list so that each returned list corresponds to only one task.
 *
 * Example:
 *
 *     test:one arg --opt + test:two --no-bool
 *
 * is transformed to:
 *
 *     test:one arg --opt
 *     test:two --no-bool
 */
List<List<String>> _splitTaskArgs(List<String> args) {
    var ret = new List<List<String>>();
    int p = 0;
    for (int i = 0; i < args.length; ++i) {
        if (args[i] == '+') {
            if (i != 0)
                ret.add(args.sublist(p, i));
            p = i + 1;
        }
        else if (args[i] == '\\+')
            args[i] = '+';
    }
    if (p != args.length)
        ret.add(args.sublist(p));
    return ret;
}

/**
 * Prints usage for all tasks.
 *
 * For each defined task, print its usage. The usage is printed manually for the required and positional arguments,
 * For the named arguments (which are options in the dake system), it uses the ArgParser's description.
 */
void _taskUsage(Map<String, Map> tasks) {
    print("dake [options] task [params]");
    print("");

    tasks.forEach((String taskName, Map desc) {
        String line = "  " + taskName;
        List<Map<String, String>> params = desc['params'];
        params.where((p) => p['req'] == 'req').forEach((p) => line += " ${p['name']}");
        params.where((p) => p['req'] == 'pos').forEach((p) => line += " [${p['name']}]");
        print(line);
        print("    ${desc['help']}");

        if (!params.isEmpty) {
            print("    Parameters:");
            var paramsLength = params.map((p) => p['name'].length + (p['req'] == 'pos' ? 6 : 4)).fold(0, max);
            params.forEach((p) {
                print("      " + (p['req'] == 'pos' ? '[${p['name']}]' : p['name']).padRight(paramsLength)
                + "(${p['dispType']}) ${p.containsKey('help') ? p['help'] : ''}");
            });
        }

        List<Map<String, String>> options = desc['options'];
        if (!options.isEmpty) {
            print("    Options:");
            print(desc['parser'].getUsage().split("\n").map((line) => "      $line").join("\n"));
        }
        print("");
    });
}
