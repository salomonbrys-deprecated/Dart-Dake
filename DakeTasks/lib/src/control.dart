
part of dake_tasks;

/**
 * The controller of dake tasks
 */
class _Control {

    /**
     * The description of all provided tasks.
     *
     * The description consists of a map that, to each task name, associates a map that contains:
     *
     *  * member: The MethodMirror to call for this task.
     *  * help: the help description of the task.
     *  * params: A list of parameters (required and positional method parameters)
     *  * options: A list of options (named method parameters)
     *
     *
     * Each param and option is a map containing:
     *
     *  * name: The name of the parameter.
     *  * type: The name of the type of the parameter (lowercase).
     *  * dispType: (optional) The name of the type of the parameter to display in the help screen.
     *  * help: (optional) the help description of the parameter.
     *  * req: (only in param) Either 'req' for required or 'pos' for positional parameter.
     *  * val: (optional, only in param) the default value of the required method parameter so it can be treated as positional.
     *  * optAbbr: (optional, only in option) the abbreviate option name for command line parsing.
     *
     * Throws an Exception if anything in the tasks is wrong (bad faked-positional parameters or bad parameter type).
     */
    final Map<String, Map<String, dynamic>> _tasks = {};

    /**
     * Creates the _tasks map.
     */
    _Control(List<Type> classes) {
        classes.forEach((type) {
            var mirror = reflectClass(type);

            Namespace namespace = _getFirstMetadata(mirror, Namespace);
            String ns = namespace != null ? namespace.name : MirrorSystem.getName(mirror.simpleName);

            _eachMemberWithMetadata(mirror, Task).forEach((MethodMirror member, Task meta) {
                String name = (ns.isEmpty ? "" : ns + ":") + MirrorSystem.getName(member.simpleName);
                name = name[0].toLowerCase() + name.substring(1);
                _tasks[name] = {
                    'member': member,
                    'help': meta.desc,
                    'params': [],
                    'options': []
                };
                bool hasPos = false;
                member.parameters.forEach((p) {
                    try {
                        _checkType(p);
                        Param paramInfo = _getFirstMetadata(p, Param);
                        var props = {
                            'name': MirrorSystem.getName(p.simpleName),
                            'type': (p.type.reflectedType == dynamic) ? 'string' : MirrorSystem.getName(p.type.simpleName).toLowerCase()
                        };
                        props['dispType'] = (paramInfo != null && paramInfo.type != null) ? paramInfo.type : props['type'];
                        if (paramInfo != null && paramInfo.desc != null)
                            props['help'] = paramInfo.desc;
                        if (p.isNamed) {
                            if (paramInfo != null && paramInfo.optAbbr != null)
                                props['optAbbr'] = paramInfo.optAbbr;
                            _tasks[name]['options'].add(props);
                        }
                        else {
                            if (paramInfo != null && paramInfo.val != _NO_VAL) {
                                props['req'] = 'pos';
                                props['val'] = paramInfo.val;
                                hasPos = true;
                            }
                            else if (p.isOptional) {
                                props['req'] = 'pos';
                                hasPos = true;
                            }
                            else {
                                props['req'] = 'req';
                                if (hasPos)
                                    throw new Exception("You cannot have non-optional parameters after optional ones");
                            }
                            _tasks[name]['params'].add(props);
                        }
                    }
                    on Exception catch (e) {
                        throw new Exception("In $name: ${e.message}");
                    }
                });
                var params = [];
            });
        });
    }

    /**
     * The isolate's transferable description of the _tasks map.
     *
     * It basically is the full description of all provided tasks minus their member (which is not transferable).
     */
    Map<String, Map<String, dynamic>> get description => new Map.fromIterable(_tasks.keys, value: (k) => new Map.from(_tasks[k])..remove('member'));

    /**
     * Call a task with the given arguments.
     *
     * If the method has absent faked positional parameters, this sets their default value before calling.
     */
    Future call(Map args) {
        return new Future.sync(() {
            Map task = _tasks[args['task']];
            MethodMirror member = task['member'];
            InstanceMirror mirror = reflect(dakeRepo[(member.owner as ClassMirror).reflectedType]);
            for (int i = 0; i < task['params'].length; ++i) {
                if (task['params'][i].containsKey('val') && args['positional'].length - 1 < i) {
                    args['positional'].add(task['params'][i]['val']);
                }
            }
            args['named'] = new Map.fromIterable(args['named'].keys, key: (k) => new Symbol(k), value: (k) => args['named'][k]);
            InstanceMirror ret = mirror.invoke(member.simpleName, args['positional'], args['named']);
            if (ret.reflectee is Future)
                return ret.reflectee;
            return new Future.value(ret.reflectee);
        });
    }
}

/**
 * Checks that the given type is valid for a task parameter.
 */
void _checkType(ParameterMirror p) {
    if (    p.type.reflectedType != String
    &&  p.type.reflectedType != bool
    &&  p.type.reflectedType != int
    &&  p.type.reflectedType != double
    &&  p.type.reflectedType != num
    &&  p.type.reflectedType != dynamic)
        throw new Exception("Parameter " + MirrorSystem.getName(p.type.qualifiedName) + " " + MirrorSystem.getName(p.qualifiedName) + " must be of type String, bool, int, double or num");
}

/**
 * Util: get the first metadata of the given type on the given mirror.
 */
dynamic _getFirstMetadata(DeclarationMirror mirror, Type type) {
    var metadata = mirror.metadata.firstWhere((m) => m.type.reflectedType == type, orElse: () => null);
    return metadata != null ? metadata.reflectee : null;
}

/**
 * Util: Return a map of all members annotated with the given metadata type
 */
Map<MethodMirror, Task> _eachMemberWithMetadata(ClassMirror mirror, Type type) {
    var ret = {};
    mirror.instanceMembers.values.forEach((member) {
        var meta = _getFirstMetadata(member, type);
        if (meta != null) ret[member] = meta;
    });
    return ret;
}
