
library dake.completion;

import 'package:args/args.dart';

class _Comp {
    final String command;
    final List<String> args;
    final int index;
    _Comp(this.command, this.args, this.index);
    toString() => "$command$args($index)";
    String get word => (index >= args.length ? null : args[index]);
}

String _getOptionName(String option) {
    if (option.startsWith("--"))
        return option.substring(2);
    else if (option.startsWith("-"))
        return option.substring(1);
    return option;

}

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

Set<String> _getDefinedOptions(List<String> args) {
    Set<String> options = new Set<String>();

    options.addAll(args.where((a) => a.startsWith(new RegExp(r'--..'))).map((a) => a.substring(2)));
    options.addAll(args.where((a) => a.startsWith(new RegExp(r'-[^-]'))).expand((a) => a.substring(1).split('')));

    return options;
}

Map _getOption(List<Map> options, String name) {
    name = _getOptionName(name);
    for (Map<String, dynamic> option in options) {
        if (option['name'] == name || option['optAbbr'] == name)
            return option;
    }
    return {};
}

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

Set<String> _completeOptions(List options, _Comp comp, bool zsh) {
    Set<String> result = new Set<String>();

    Set<String> defined = new Set<String>();
    if (comp.args.isNotEmpty)
        defined = _getDefinedOptions(comp.args);

    if (comp.word != null)
        defined.remove(_getOptionName(comp.word));

    bool appendAbbr = (comp.word != null && comp.word.length >= 2 && !comp.word.startsWith("--"));
    if (appendAbbr) {
        String type = _getOption(options, comp.word.substring(comp.word.length - 1))['type'];
        if (type != null && type != "bool")
            appendAbbr = false;
    }

    var addResult = (String name, String desc) {
        if (!zsh || desc == null)
            return result.add(name);
        result.add("'$name[$desc]'");
    };

    options
        .where((Map option) => !(defined.contains(option['name']) || (option['optAbbr'] != null && defined.contains(option['optAbbr']))))
        .forEach((Map option) {
            addResult("--${option['name']}", option['help']);
            if (option["type"] == "bool")
                addResult("--no-${option['name']}", option['help']);
            if (option["optAbbr"] != null) {
                addResult("-${option['optAbbr']}", option['help']);
                if (appendAbbr && option['optAbbr'] == "bool" && !comp.word.contains(option['optAbbr']))
                    addResult(comp.word + option['optAbbr'], option['help']);
            }
        })
    ;

    if (comp.word != null && comp.word.startsWith(new RegExp(r'-[^-]')))
        result.add(comp.word);

    return result;
}

void _printArgType(String valueType) {
    if (valueType == "filedir" || valueType == "path")
        valueType = "file";
    if (["file", "dir"].contains(valueType))
        return print("::$valueType::");

    if (valueType.contains("|"))
        print(valueType.split("|").join(" "));
}

List<String> _paramArgs(List<String> args, List<Map> options) {
    List<String> ret = [];
    int i = 0;
    while (i < args.length) {
        if (!args[i].startsWith("-"))
            ret.add(args[i]);
        else {
            Map option = _getOption(options, args[i]);
            if (option != null && option['type'] != "bool")
                ++i;
        }
        ++i;
    }
    return ret;
}

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

Iterable<String> _taskNames(Map<String, Map> tasks, bool zsh) {
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

void completion(Map<String, Map> tasks, int pos, List<String> args) {
    Set<String> result = new Set<String>();

    bool zsh = false;

    if (args[0] == "__zsh__") {
        args.removeAt(0);
        zsh = true;
    }

    _Comp comp = _getCurrentCommand(pos, args);
    if (comp == null) {
        result.addAll(_taskNames(tasks, zsh));
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
