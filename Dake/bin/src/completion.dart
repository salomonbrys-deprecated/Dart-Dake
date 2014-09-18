
library dake.completion;

import 'package:args/args.dart';

/**
 * Contains the informations of the current command completion query.
 */
class _Comp {
    /** The command being completed. */
    final String command;
    /** The arguments list. does not conaits the command. */
    final List<String> args;
    /** The index of the argument being completed. */
    final int index;

    _Comp(this.command, this.args, this.index);
    toString() => "$command$args($index)";
    /** The word being completed. If it is after the last argument, is null. */
    String get word => (index >= args.length ? null : args[index]);
}

/**
 * Get all names of a given options.
 *
 * --ful-option => [ 'full-option' ]
 * -a           => [ 'a' ]
 * -abc         => [ 'a', 'b', 'c' ]
 * no_hyphen    => [ 'no_hyphen' ]
 */
List<String> _getOptionNames(String option) {
    if (option.startsWith("--"))
        return [option.substring(2)];
    else if (option.startsWith("-"))
        return option.substring(1).split("");
    return [option];

}

/**
 * Get the _Comp object representing the current command being completed.
 *
 * Returns null if it cannot find a command (for example, the first word after a + is a command.
 * if it is that word that is being completed, then there is no command being completed, so returns null)
 */
_Comp _getCurrentCommand(int pos, List<String> args) {
    if (pos == 0 || (pos - 1 < args.length && args[pos - 1] == "+"))
        return null;

    if (pos < args.length && (args[pos] == "+"))
        return new _Comp("+", [], 0);

    int start = pos;
    if (start >= args.length)
        start = args.length - 1;
    while (start > 0) {
        if (args[start] == "+") {
            ++start;
            break ;
        }
        --start;
    }

    int end = start;
    while (end < args.length) {
        if (args[end] == "+")
            break ;
        ++end;
    }

    return new _Comp(args[start], args.sublist(start + 1, end), pos - start - 1);
}

/**
 * Get a set of all defined options in an array of parameters
 *
 * Example: ['param', '--option', '-ab'] => ['option', 'a', 'b']
 */
Set<String> _getDefinedOptions(List<String> args) {
    Set<String> options = new Set<String>();

    options.addAll(args.where((a) => a.startsWith(new RegExp(r'--..'))).map((a) => a.substring(2)));
    options.addAll(args.where((a) => a.startsWith(new RegExp(r'-[^-]'))).expand((a) => a.substring(1).split('')));

    return options;
}

/**
 * Get the option map description from its name.
 */
Map _getOption(List<Map> options, String name) {
    name = _getOptionNames(name)[0];
    for (Map<String, dynamic> option in options) {
        if (option['name'] == name || option['optAbbr'] == name)
            return option;
    }
    return {};
}

/**
 * Returns the type of the last option's value, if any.
 *
 * Let's say that we are completing the word after --output-file,
 * since this option has a file parameter, will return 'file'.
 *
 * Returns null if this is not a position for an option's value.
 */
String _isLastOptionWaitingForValue(_Comp comp, List<Map> options) {
    if (comp.index == 0)
        return null;
    String last = comp.args[comp.index - 1];
    if (!last.startsWith("-"))
        return null;
    String type = null;
    if (last.startsWith("-"))
        type = _getOption(options, last)['dispType'];
    if (type == null || type == "bool")
        return null;
    return type;
}

/**
 * Returns a set of possible options to complete at this completion query.
 *
 * Will return only the options that are not already defined.
 *
 * If zsh is true, it will return the options in the zsh format with their description.
 */
Set<String> _completeOptions(List options, _Comp comp, bool zsh) {
    Set<String> result = new Set<String>();

    Set<String> defined = new Set<String>();
    if (comp.args.isNotEmpty)
        defined = _getDefinedOptions(comp.args);

    if (comp.word != null)
        defined.removeAll(_getOptionNames(comp.word));

    void _addResult(String name, String desc) {
        if (!zsh || desc == null) {
            result.add(name);
            return ;
        }
        result.add("'$name[$desc]'");
    };

    options
        .where((Map option) => !(defined.contains(option['name']) || (option['optAbbr'] != null && defined.contains(option['optAbbr']))))
        .forEach((Map option) {
            _addResult("--${option['name']}", option['help']);
            if (option["type"] == "bool")
                _addResult("--no-${option['name']}", option['help'] != null ? "Disables ${option['name']}" : null);
            if (option["optAbbr"] != null) {
                _addResult("-${option['optAbbr']}", option['help']);
            }
        })
    ;

    return result;
}

/**
 * if valueType is a special type, prints this type.
 *
 * Currently, three types are supported :
 *  - file, filedir, path
 *  - dir, folder
 *  - list|of|valid|values
 */
void _printArgType(String valueType) {
    if (valueType == "filedir" || valueType == "path")
        valueType = "file";
    if (valueType == "folder")
        valueType = "dir";
    if (["file", "dir"].contains(valueType))
        return print("::$valueType::");

    if (valueType.contains("|"))
        print(valueType.split("|").join(" "));
}

/**
 * Returns a list of arguments that are parameters and not options.
 *
 * Takes into account options that take a value as these values are not parameters.
 *
 * Example: ['Salomon', '--output-file', '/tmp/test42', 'Brys', 'France'] => ['Salomon', 'Brys', 'France']
 */
List<String> _paramArgs(List<String> args, List<Map> options) {
    List<String> ret = [];
    int i = 0;
    while (i < args.length) {
        if (!args[i].startsWith("-"))
            ret.add(args[i]);
        else if (args[i].length > 1) {
            Map option = _getOption(options, args[i]);
            if (option != null && option['type'] != "bool")
                ++i;
        }
        ++i;
    }
    return ret;
}

/**
 * Returns the index of the parameter being completed.
 *
 * Example with index 3: ['Salomon', '--output-file', '/tmp/test42', 'Brys', 'France'] => 1
 * since 'Brys' is the second parameter (index 1).
 */
int _paramIndex(List<String> args, List<Map> options, int index) {
    int ret = 0;
    int i = 0;
    while (i < index && i < args.length) {
        if (!args[i].startsWith("-"))
            ++ret;
        else {
            Map option = _getOption(options, args[i]);
            if (option != null && option['type'] != "bool")
                ++i;
        }
        ++i;
    }
    return ret;
}

/**
 * Returns a set of possible commands (= task names) to complete.
 *
 * If zsh is true, it will return the commands in the zsh format with their description.
 */
Iterable<String> _completeCommands(Map<String, Map> tasks, bool zsh) {
    if (!zsh)
        return tasks.keys;

    return tasks.keys.map((name) {
        String help = tasks[name]['help'];
        if (help != null) {
            return "'$name[$help]'";
        }
        return name;
    });
}

/**
 * Prints to standard output the possible completion given the completion query.
 *
 * Parameter tasks: The description of all tasks provided by the DakeTasks.dart.
 * Parameter pos: The position of word to complete in args.
 *                May be args.length in which case we are completing the word after args.
 * Parameter args: All arguments to dake that are already written on command line shell.
 */
void completion(Map<String, Map> tasks, int pos, List<String> args) {
    Set<String> result = new Set<String>();

    bool zsh = false;

    if (args.isNotEmpty && args[0] == "__zsh__") {
        args.removeAt(0);
        zsh = true;
    }

    _Comp comp = _getCurrentCommand(pos, args);
    if (comp == null) {
        result.addAll(_completeCommands(tasks, zsh));
    }
    else if (comp.command != "+") {
        Map<String, dynamic> task = tasks[comp.command];
        if (task != null) {
            String valueType = _isLastOptionWaitingForValue(comp, task['options']);
            if (valueType != null)
                return _printArgType(valueType);
            List<String> paramArgs = _paramArgs(comp.args, task['options']);
            bool paramsDone = (paramArgs.length >= task['params'].length);
            if ((comp.word == null && paramsDone) || (comp.word != null && comp.word.startsWith("-")))
                result.addAll(_completeOptions(task['options'], comp, zsh));
            else {
                int paramIndex = _paramIndex(comp.args, task['options'], comp.index);
                if (paramIndex < task['params'].length) {
                    return _printArgType(task['params'][paramIndex]['dispType']);
                }
            }
            if (paramsDone && comp.word == null)
                result.add("+");
        }
    }
    if (pos != 0 && pos < args.length && args[pos] == "+")
        result.add("+");

    print(result.join(" "));
}
