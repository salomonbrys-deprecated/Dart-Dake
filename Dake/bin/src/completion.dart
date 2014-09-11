
library dake.completion;

void completion(Map<String, Map> tasks, int pos, List<String> args) {
    --pos;
    if (pos == 0 || args[pos - 1] == "+")
        print(tasks.keys.join(" "));
    print("coucou le monde");
}
