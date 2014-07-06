
part of dake_tasks_tests;

class DependencyFailure {
    int _value;
    DependencyFailure(this._value);

    _test() {}
}

class DependencyTasks {

    static bool one_called = false;
    static bool two_called = false;

    @Task("A first description")
    one() {
        (dakeRepo[SimpleTasks] as SimpleTasks).one();
        one_called = true;
    }

    @Task("A second description")
    two() {
        this.one();
        two_called = true;
    }

    @Task("A third description")
    three() {
        (dakeRepo[DependencyFailure] as DependencyFailure)._test();
    }

    static void tests() {
        group('Dependencies', () {
            test('Calls', () {
                return _dakeMainTest([SimpleTasks, DependencyTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    SimpleTasks.one_called = false;
                    DependencyTasks.one_called = false;
                    DependencyTasks.two_called = false;
                    sendPort.send({ 'task': 'dependencyTasks:two', 'positional': [], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isTrue);
                        expect(DependencyTasks.one_called, isTrue);
                        expect(DependencyTasks.two_called, isTrue);
                        expect(SimpleTasks.one_called, isTrue);
                    });
                });
            });

            test('Failure', () {
                return _dakeMainTest([DependencyTasks], (Stream stream, SendPort sendPort, Map tasks) {
                    sendPort.send({ 'task': 'dependencyTasks:three', 'positional': [], 'named': {} });
                    return stream.first.then((bool success) {
                        expect(success, isFalse);
                    });
                }, noError: NoSuchMethodError);
            });
        });
    }
}
