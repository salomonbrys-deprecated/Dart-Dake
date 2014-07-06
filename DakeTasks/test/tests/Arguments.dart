
part of dake_tasks_tests;

class BadPositionalTasks {
    @Task("Bad")
    bad(@Param(val: false) bool b, int i) {}
}

@Namespace("args")
class ArgumentsTasks {

    static bool   one_b;
    static String one_s;
    static bool   two_b;
    static String two_s;

    @Task("Only positional")
    one(int i, [ bool b, String path = "/tmp" ]) {
        one_b = b;
        one_s = path;
    }

    @Task("Both positional and named")
    two( int i,
         @Param(val: false) bool b,
         {
             @Param(optAbbr: "p") String path: "/tmp"
         }
         ) {
        two_b = b;
        two_s = path;
    }

    static const DESC = const {
        'args:one': const {
            'help': 'Only positional',
            'params': const [
                const {'name': 'i', 'type': 'int', 'dispType': 'int', 'req': 'req'},
                const {'name': 'b', 'type': 'bool', 'dispType': 'bool', 'req': 'pos'},
                const {'name': 'path', 'type': 'string', 'dispType': 'string', 'req': 'pos'}
            ],
            'options': const []
        },
        'args:two': const {
            'help': 'Both positional and named',
            'params': const [
                const {'name': 'i', 'type': 'int', 'dispType': 'int', 'req': 'req'},
                const {'name': 'b', 'type': 'bool', 'dispType': 'bool', 'req': 'pos', 'val': false}
            ],
            'options': const [const {'name': 'path', 'type': 'string', 'dispType': 'string', 'optAbbr': 'p'}]
        }
    };

    static void tests() {
        group('Arguments', () {
            test('Description', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    expect(tasks, equals(ArgumentsTasks.DESC));
                });
            });

            test('Call with no positional arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.one_b = null;
                    ArgumentsTasks.one_s = null;
                    sendPort.send({ 'task': 'args:one', 'positional': [42], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.one_b, isNull);
                        expect(ArgumentsTasks.one_s, equals("/tmp"));
                    });
                });
            });

            test('Call with one positional arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.one_b = null;
                    ArgumentsTasks.one_s = null;
                    sendPort.send({ 'task': 'args:one', 'positional': [42, true], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.one_b, isTrue);
                        expect(ArgumentsTasks.one_s, equals("/tmp"));
                    });
                });
            });

            test('Call with two positional arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.one_b = null;
                    ArgumentsTasks.one_s = null;
                    sendPort.send({ 'task': 'args:one', 'positional': [42, true, null], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.one_b, isTrue);
                        expect(ArgumentsTasks.one_s, isNull);
                    });
                });
            });

            test('Call with no positional or named arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.two_b = null;
                    ArgumentsTasks.two_s = null;
                    sendPort.send({ 'task': 'args:two', 'positional': [42], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.two_b, isFalse);
                        expect(ArgumentsTasks.two_s, equals("/tmp"));
                    });
                });
            });

            test('Call with only positional arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.two_b = null;
                    ArgumentsTasks.two_s = null;
                    sendPort.send({ 'task': 'args:two', 'positional': [42, null], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.two_b, isNull);
                        expect(ArgumentsTasks.two_s, equals("/tmp"));
                    });
                });
            });

            test('Call with only named arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.two_b = null;
                    ArgumentsTasks.two_s = null;
                    sendPort.send({ 'task': 'args:two', 'positional': [42], 'named': {'path': null} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.two_b, isFalse);
                        expect(ArgumentsTasks.two_s, isNull);
                    });
                });
            });

            test('Call with both positional and named arguments', () {
                return _dakeMainTest([ArgumentsTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    ArgumentsTasks.two_b = null;
                    ArgumentsTasks.two_s = null;
                    sendPort.send({ 'task': 'args:two', 'positional': [42, true], 'named': {'path': "/home/salomon"} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(ArgumentsTasks.two_b, isTrue);
                        expect(ArgumentsTasks.two_s, equals("/home/salomon"));
                    });
                });
            });

            test('Bad optional argument declaration', () {
                try {
                    _dakeMainTest([BadPositionalTasks], (Stream stream, SendPort sendPort, Map tasks) {});
                    fail("Exception should have been thrown");
                }
                catch (e) {
                    expect(e.toString(), equals("Exception: In badPositionalTasks:bad: You cannot have non-optional parameters after optional ones"));
                }
            });
        });
    }
}

