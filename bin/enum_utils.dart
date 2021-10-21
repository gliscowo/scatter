bool Function(String) enumMatcher(List<Enum> enumValues) {
  return (string) => enumValues.any((element) => getName(element) == string);
}

T getEnum<T extends Enum>(List<T> enumValues, String name) {
  return enumValues.singleWhere((element) => getName(element) == name);
}

String getName<T extends Enum>(T instance) {
  return instance.toString().split('.')[1];
}