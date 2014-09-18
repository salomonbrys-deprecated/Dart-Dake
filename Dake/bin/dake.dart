/**
 * The dake program.
 */
library dake;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'src/tasks.dart';

/**
 * Checks that packages/dake_tasks exists and starts program accordingly.
 *
 *  * If it does not, run pub get to get it (hoping that it is declared in the pubspec.yaml file)
 *  * If it does, run the program as it should with the function _main
 *
 */
void main(List<String> args) {
    var parser = new ArgParser();
    parser.addFlag('help', help: 'This help', negatable: false);
    parser.addOption('file', abbr: 'f', help: 'The task dart file if not DakeTasks.dart');

    ArgResults argResult;
    try {
        argResult = parser.parse(args);
    }
    on FormatException catch(e) {
        print(e.message);
        dakeUsage(parser);
        exit(1);
    }
    if (argResult['help']) {
        dakeUsage(parser);
        return ;
    }

    if (argResult['file'] != null) {
        var file = new File(argResult['file']);
        file.exists().then((exists) {
            if (!exists) {
                print("${argResult['file']} not found");
                exit(1);
            }
            Directory.current = path.dirname(argResult['file']);
            _start(argResult.rest, path.basename(argResult['file']), null);
        });
        return ;
    }

    String basePath = Directory.current.path;
    _findDakeTasks().then((found) {
        if (!found) {
            if (args.length >= 1 && args[0] == "__completion__")
                exit(0);
            print("No DakeTasks.dart");
            exit(1);
        }
        _checkAndStart(argResult.rest, "DakeTasks.dart", basePath);
    });
}

/**
 * Finds the closest DakeTasks.dart file in the directory tree
 * and changes current directory to set it to the directory containing DakeTasks.dart
 *
 * Returns a future that completes with whether the DakeTasks.dart file has been found or not.
 */
Future<bool> _findDakeTasks() {
    var check;
    check = () {
        return new File(Directory.current.path + "/DakeTasks.dart").exists().then((exists) {
            if (exists)
                return true;
            if (Directory.current.path == "/")
                return false;
            Directory.current = "..";
            return check();
        });
    };
    return check();
}

/**
 * Checks that the packages directory exists and contains the package dake_tasks.
 *
 * If it does not, it will call _pubget to run pub get and install the dependencies.
 */
void _checkAndStart(List<String> args, String file, String basePath) {
    void _recheck(_) {
        if (!new Directory(Directory.current.path + "/packages/dake_tasks").existsSync()) {
            print("No packages/dake_tasks directory, is dake_tasks declared in the pubspec.yaml dependencies?");
            exit(1);
        }
        _start(args, file, basePath);
    }

    if (!new Directory(Directory.current.path + "/packages").existsSync()) {
        print("No packages directory");
        _pubget().then(_recheck);
    }
    else if (!new Directory(Directory.current.path + "/packages/dake_tasks").existsSync()) {
        print("No packages/dake_tasks directory");
        _pubget().then(_recheck);
    }
    else
        _start(args, file, basePath);
}

/**
 * Runs pub get.
 *
 * Returns a future that is completed when pub get ran successfuly and the directory packages/dake_tasks exists.
 */
Future _pubget() {
    print("Running pub get");
    return Process.start("pub", ["get"], runInShell: true).then((Process p) {
        p.stdout.listen((List<int> data) => stdout.add(data));
        p.stderr.listen((List<int> data) => stderr.add(data));
        return p.exitCode.then((int code) {
            if (code == 127)
                throw new Exception("Looks like command pub was not found. Is it in the path?");
            if (code != 0)
                exit(code);
            if (!new Directory(Directory.current.path + "/packages/dake_tasks").existsSync())
                throw new Exception("No package dake_tasks, have you forgotten to put the dake_tasks dependency in pubspec.yaml?");
        });
    }).catchError((e) {
        print("Error: ${e.message}");
        exit(1);
    });
}

/**
 * Runs the dake workflow.
 *
 * The workflow consists of:
 *
 *  1. Checking the dake parameters and treating them (for example, `--help`).
 *  2. Checking that the DakeTasks.dart file exists
 *  3. Spawning an isolate that will run DakeTasks.dart and establishing a two way communication (SendPort/ReceivePort) with it
 *  4. Handling command line given tasks
 */
_start(List<String> args, String file, String basePath) {

    Uri taskFile = Uri.parse(Directory.current.path + "/" + file);

    var receivePort = new ReceivePort();

    Isolate.spawnUri(taskFile, ["__DAKE__", 0], receivePort.sendPort).then((_) {
        var receiveStream = receivePort.asBroadcastStream();
        receiveStream.first
        .then((Map result) {
            SendPort sendPort = result['sendPort'];
            return handleTasks(sendPort, receiveStream, basePath, result['tasks'], args).then((_) => sendPort.send({}));
        })
        .then((_) => receivePort.close())
        ;
    });
}

/**
 * Prints usage.
 */
void dakeUsage(parser) {
    print("dake [options] task [params]");
    print(parser.getUsage());
    print("Run `dake` in a directory with a DakeTasks.dart file to list all commands and options");
}
