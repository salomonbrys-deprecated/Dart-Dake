
# Dake

Dake is a dart command line task runner. It is the make of dart, much like rake for ruby.  
It is designed to allow dart applications to have their maintenance & build tasks written in a dart file while allowing a simple and powerful way to run them.


## Install Dake

___TODO: Use Pubin___


## Use Dake

You can use Dake to run tasks that are defined in a `DakeTasks.dart` file.

To list all tasks available, simply run `dake` in the directory containing the `DakeTasks.dart` file. It will list all available tasks, there required arguments, optional arguments and named options.

To run a task, simply write `dake task-name arguments`. For example:

    dake dev:version 4 2 --postfix beta
    
...will run the task `dev:version` with the arguments `4`, `2` and the named option `postfix = 'beta'`.

    dake assets:minify --build

...will run the task `assets:minify` with the `build` boolean flag set.

You can run multiple tasks serially with the `+` symbol:

    dake dev:version 4 2 --postfix beta + assets:minify --build + dev:server 8080
    
...will run all the tasks `dev:version`, `assets:minify` and `dev:server` one after the other.

You can have fun with Dake in the `DakeExample` directory: an example DakeTasks.dart is given to experiment with Dake.


## Write Dake tasks

A `DakeTasks.dart` file is a dart command line application that uses the package `dake_tasks`.

First add the dependency to `pubspec.yaml`:

    dependencies:
      dake_tasks: ">=1.0.0 <2.0.0"

In your `DartTasks.dart`, import the package:
    
    import 'package:dake_tasks/dake_tasks.dart';

**Read the example file `DakeExample/DakeTasks.dart`. It is properly documented explains all features of the package `dake_tasks`.**

Finally, once all task classes have been defined, write the main function as followed:

    main(args, replyTo) => DakeMain([list, of, task, classes], args, replyTo);