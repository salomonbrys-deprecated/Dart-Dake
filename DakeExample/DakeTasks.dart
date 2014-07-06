
import 'dart:async';

// Import dake_tasks to define your tasks
import 'package:dake_tasks/dake_tasks.dart';

// This is a class that contains tasks
class Assets implements DakeClosable {

    // Task classes are singleton, which means that a single instance of a task class will be created
    // regardless of the number of tasks that will be run on that class.
    // Which means that the constructor of a task class will be called only once.
    Assets() {
        print("Opening assets");
    }

    // A task can return a future. If it does not, it is considered sync.
    @Task("Build the assets")
    build() {
        print("Building the assets...");
        return new Future.delayed(const Duration(seconds: 1)).then((_) => print("OK") );
    }

    // Tasks can have named arguments which are translated into command line options
    // @Param.optAbbr allows to define a abbreviated command line option
    @Task("Minify the assets")
    minify({@Param(optAbbr: "b") bool build}) {
        var bf = new Future.value();
        if (build)
            bf = this.build();
        return bf.then((_) {
            print("Minifying assets...");
            print("OK");
        });
    }

    // This class implements DakeClosable which is a destructor : it is called once all the tasks have been run.
    void close() {
        print("Closing assets");
    }
}

// By default each class defines a namespace of its name (with the first letter lowercased).
// You can use @Namespace to change that namespace.
// You can use @Namespace with an empty string to define that the tasks in the class will not have namespace.
@Namespace("dev")
class Development {

    // A task can have optional positional parameters.
    // @Param.type allows to define a display type that is displayed on the help of the task.
    // @Param.desc allows to define a description of the parameter displayed on the help of the task.
    @Task("Run the server")
    server([@Param(desc: "The port to listen to") int port, @Param(type: "adress", desc: "The address to listen to") String bind]) {
        return dakeRepo[Assets].build().then((_) {
            print("The server is running");
            return new Completer().future;
        });
    }

    // A task can have both optional positional and named parameters.
    // Since dart does not allows this feature in the language, it is emulated with @Param.val.
    @Task("Set version name in files")
    version(int major, @Param(val: 0) int minor, { String postfix: "" }) {
        if (!postfix.isEmpty)
            postfix = "-$postfix";
        print("New version is: $major.$minor$postfix");
    }
}

// In your main, you must call DakeMain and pass it your task classes, the program arguments and the isolate SendPort.
main(args, replyTo) => DakeMain([Assets, Development], args, replyTo);

