import 'package:recase/recase.dart';
import 'package:dart_style/dart_style.dart';
import 'package:inflection2/inflection2.dart';

import 'package:flutter_schema_parse/model.dart';

const String _objectType = 'object';
const String _arrayType = 'array';

const Map<String, String> _typeMap = <String, String>{
  'integer': 'int',
  'string': 'String',
  'number': 'num',
};

class JsonSchemaParser {
  static String _getClassName(String type, String name) => type == _objectType
      ? ReCase(name).pascalCase
      : type == _arrayType ? convertToSingular(ReCase(name).pascalCase) : null;

  static String _getObjectType(String type, String name) => type == _objectType
      ? _getClassName(type, name)
      : type == _arrayType
          ? 'List<${_getClassName(type, name)}>'
          : _typeMap[type];

  static String _getClasses(String className, List<Model> models) {
    StringBuffer result = StringBuffer();

    result.write('class $className {');
    result.write(_buildContractor(className, models));
    result.write(_buildFromJson(className, models));
    result.write(_buildToJson(models));
    result.write('}');

    return DartFormatter().format(result.toString());
  }

  static StringBuffer _buildContractor(String className, List<Model> models) {
    StringBuffer result = StringBuffer();

    for (Model model in models) {
      result.write('${model.type} ${model.title};');
    }

    result.write('$className({');

    for (Model model in models) {
      result.write('${model.title},');
    }

    result.write('});');

    return result;
  }

  static StringBuffer _buildFromJson(String className, List<Model> models) {
    StringBuffer result = StringBuffer();

    result.write('$className.fromJson(Map<String, dynamic> json) {');

    for (Model model in models) {
      if (model.schemaType == _objectType) {
        result.write('''
          ${model.title} = json['${model.schemaTitle}'] != null
            ? ${model.className}.fromJson(json['${model.schemaTitle}'])
            : null;
        ''');
      } else if (model.schemaType == _arrayType) {
        result.write('''
          if (json['${model.schemaTitle}'] != null) {
            ${model.title} = List<${model.className}>();
            
            json['${model.schemaTitle}'].forEach((item) {
              ${model.className}.add(${model.className}.fromJson(item));
            });
          }
        ''');
      } else {
        result.write('''${model.title} = json['${model.schemaTitle}'];''');
      }
    }

    result.write('}');

    return result;
  }

  static StringBuffer _buildToJson(List<Model> models) {
    StringBuffer result = StringBuffer();

    result.write('Map<String, dynamic> toJson() {');
    result.write('final Map<String, dynamic> data = Map<String, dynamic>();');

    for (Model model in models) {
      if (model.schemaType == _objectType) {
        result.write('''
          if (${model.title} != null) {
            data['${model.schemaTitle}'] = ${model.title}.toJson();
          }
        ''');
      } else if (model.schemaType == _arrayType) {
        result.write('''
          if (${model.title} != null) {
            data['${model.schemaTitle}'] =
                ${model.title}.map((item) => item.toJson()).toList();
          }
        ''');
      } else {
        result.write('''data['${model.schemaTitle}'] = ${model.title};''');
      }
    }

    result.write('return data;');
    result.write('}');

    return result;
  }

  static List<Model> getModel(Map<String, dynamic> schema) {
    List<Model> parent = [];

    if (schema['properties'] != null) {
      for (var entry in schema['properties'].entries) {
        Model child = Model();

        child.className = _getClassName(entry.value['type'], entry.key);
        child.title = ReCase(entry.key).camelCase;
        child.type = _getObjectType(entry.value['type'], entry.key);
        child.schemaTitle = entry.key;
        child.schemaType = entry.value['type'];
        child.children = [];

        if (entry.value['type'] == _objectType) {
          child.children.addAll(getModel(entry.value));
        } else if (entry.value['type'] == _arrayType) {
          child.children.addAll(getModel(entry.value['items']));
        }

        parent.add(child);
      }
    }

    return parent;
  }

  static void getAllClasses(String className, List<Model> models) {
    if (models.isNotEmpty) {
      print(JsonSchemaParser._getClasses(className, models));
    }

    for (Model model in models) {
      getAllClasses(model.className, model.children);
    }
  }
}
