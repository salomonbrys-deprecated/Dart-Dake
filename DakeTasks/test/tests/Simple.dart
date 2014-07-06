
part of dake_tasks_tests;

class BadTypeTasks {
    @Task("Bad")
    bad(int i, Symbol s) {}
}

class SimpleTasks {

    static bool one_called = false;
    static bool two_called = false;

    @Task("A first description")
    one() {
        one_called = true;
    }

    @Task("A second description")
    two(String s,
        int i,
        double d,
        @Param(desc: "A description") num n,
        bool b,
        dyn
        ) {
        two_called = true;
    }

    static int fut_time = null;
    static const _DURATION = const Duration(milliseconds: 100);
    @Task("A future")
    fut() {
        return new Future.delayed(_DURATION, () {
            fut_time = new DateTime.now().millisecondsSinceEpoch;
        });
    }


    static const DESC = const {
        'simpleTasks:one': const {'help': 'A first description', 'params': const [], 'options': const []},
        'simpleTasks:two': const {
            'help': 'A second description',
            'params': const [
                const {'name': 's', 'type': 'string', 'dispType': 'string', 'req': 'req'},
                const {'name': 'i', 'type': 'int', 'dispType': 'int', 'req': 'req'},
                const {'name': 'd', 'type': 'double', 'dispType': 'double', 'req': 'req'},
                const {'name': 'n', 'type': 'num', 'dispType': 'num', 'help': 'A description', 'req': 'req'},
                const {'name': 'b', 'type': 'bool', 'dispType': 'bool', 'req': 'req'},
                const {'name': 'dyn', 'type': 'string', 'dispType': 'string', 'req': 'req'}
            ],
            'options': const []
        },
        'simpleTasks:fut': const {'help': 'A future', 'params': const [], 'options': const []}
    };

    static void tests() {
        group('Simple', () {
            test('Class with arguments', () {
                return _dakeMainTest([SimpleTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    expect(tasks, equals(SimpleTasks.DESC));
                });
            });

            test('Call without arguments', () {
                return _dakeMainTest([SimpleTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    SimpleTasks.one_called = false;
                    sendPort.send({ 'task': 'simpleTasks:one', 'positional': [], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(SimpleTasks.one_called, isTrue);
                    });
                });
            });

            test('Call with arguments', () {
                return _dakeMainTest([SimpleTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    SimpleTasks.two_called = false;
                    sendPort.send({ 'task': 'simpleTasks:two', 'positional': ["Salomon", 42, 21.42, 42.21, true, ""], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(SimpleTasks.two_called, isTrue);
                    });
                });
            });

            test('Call that returns a future', () {
                return _dakeMainTest([SimpleTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    sendPort.send({ 'task': 'simpleTasks:fut', 'positional': [], 'named': {} });
                    SimpleTasks.fut_time = null;
                    var start = new DateTime.now().millisecondsSinceEpoch;
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(SimpleTasks.fut_time - start, greaterThanOrEqualTo(100));
                    });
                });
            });

            test('Missing arguments', () {
                return _dakeMainTest([SimpleTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    sendPort.send({ 'task': 'simpleTasks:two', 'positional': ["Salomon"], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isFalse);
                    });
                }, noError: NoSuchMethodError);
            });

            // This test will fail if dart is not run in checked mode
            test('Bad arguments', () {
                return _dakeMainTest([SimpleTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    sendPort.send({ 'task': 'simpleTasks:two', 'positional': [42, 21.42, 42.21, true, "Salomon", ""], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isFalse);
                    });
                }, noError: TypeError);
            });

            test('Bad argument type', () {
                try {
                    _dakeMainTest([BadTypeTasks], (Stream stream, SendPort sendPort, Map tasks) {});
                    fail("Exception should have been thrown");
                }
                catch (e) {
                    expect(e.toString(), equals("Exception: In badTypeTasks:bad: Parameter dart.core.Symbol dake_tasks_tests.BadTypeTasks.bad.s must be of type String, bool, int, double or num"));
                }
            });
        });
    }
}
