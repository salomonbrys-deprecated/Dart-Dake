
library dake_tasks_tests;

import 'dart:isolate';
import 'dart:async';
import 'dart:mirrors';

import 'package:unittest/unittest.dart';

import '../lib/dake_tasks.dart';

part 'tests/Simple.dart';
part 'tests/Dependency.dart';
part 'tests/Arguments.dart';

_dakeMainTest(List<Type> taskClasses, Function cb, {Type noError}) {
    var rp = new ReceivePort();
    var args = ["__DAKE__"];
    if (noError != null)
        args.add("NoError:" + MirrorSystem.getName(reflectClass(noError).simpleName));
    try {
        DakeMain(taskClasses, args, rp.sendPort);
    }
    catch (e) {
        rp.close();
        throw e;
    }
    var rpStream = rp.asBroadcastStream();
    SendPort sendPort;
    return rpStream.first.then((Map desc) {
        sendPort = desc['sendPort'];
        return cb(rpStream, sendPort, desc['tasks']);
    }).whenComplete(() {
        rp.close();
        sendPort.send({});
    });
}

main() {
    group('Connect', () {
        ReceivePort rp;

        setUp(() => rp = new ReceivePort());
        tearDown(() => rp.close());

        test('DakeMain', () {
            expect(() => DakeMain(null, null, null), throws);
            expect(() => DakeMain([], [], rp.sendPort), throws);
        });

        test('First dake message', () {
            DakeMain([], ["__DAKE__"], rp.sendPort);
            return rp.first.then((Map desc) {
                expect(desc['sendPort'], new isInstanceOf<SendPort>('SendPort'));
                expect(desc['tasks'], new isInstanceOf<Map>('Map'));
                (desc['sendPort'] as SendPort).send({});
            });
        });

        test('Empty task class', () {
            return _dakeMainTest([], (Stream stream, SendPort sendPort, Map tasks) {
                expect(tasks, equals({}));
            });
        });
    });

    SimpleTasks.tests();

    DependencyTasks.tests();

    ArgumentsTasks.tests();
}
