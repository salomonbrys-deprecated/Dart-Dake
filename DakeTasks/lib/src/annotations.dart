
part of dake_tasks;

/**
 * Annotation: A task in a task class.
 */
class Task {
    /**
     * The description of the task.
     */
    final String desc;

    const Task(this.desc);
}

/**
 * Annotation: The namespace of a task class.
 *
 * By default, each task class defines a namespace of its name.
 * You can use this annotation if you want to change the namespace of a task class.
 */
class Namespace {
    /**
     * The name of the namespace.
     */
    final String name;

    const Namespace(this.name);
}

const _NO_VAL = "\0/^\0/^\0/^\0/^\0/";

/**
 * Annotation: The Parameter informataion of a task parameter.
 *
 * This is optional: it provides additional information and features to a task parameter.
 */
class Param {
    /**
     * The description of the parameter (for the help screen).
     */
    final String desc;

    /**
     * The default value when using both positional and named optional parameters (see documentation).
     */
    final dynamic val;

    /**
     * The type to display in the help screen for this argument.
     */
    final String type;

    /**
     * Only applicable to named arguments: the abbreviated name for the command line option.
     */
    final String optAbbr;

    const Param({this.desc, this.val: _NO_VAL, this.type, this.optAbbr});
}

