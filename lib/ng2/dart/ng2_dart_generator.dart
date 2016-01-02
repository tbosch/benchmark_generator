library benchmark_generator.ng2_dart_generator;

import 'dart:math';
import 'package:benchmark_generator/generator.dart';

class Ng2DartGenerator implements Generator {
  final _fs = new VFileSystem();
  AppGenSpec _genSpec;
  final Random random = new Random(1234);

  VFileSystem generate(AppGenSpec genSpec) {
    _genSpec = genSpec;
    _generatePubspec();
    _generateIndexHtml();
    _generateIndexDart(_genSpec.components.keys);
    _genSpec.components.values.forEach(_generateComponentFiles);
    return _fs;
  }

  _addFile(String path, String contents) {
    _fs.addFile(path, contents);
  }

  void _generatePubspec() {
    _addFile('pubspec.yaml', '''
name: ${_genSpec.name}
version: 0.0.0
dependencies:
  angular2:
    path: /Users/tbosch/projects/benchmark_generator/build/ng2a/dart/angular2
  browser: any
transformers:
- angular2:
    entry_points:
      - web/index.dart
    reflection_entry_points:
      - web/index.dart
- \$dart2js:
    minify: false
    commandLineOptions: [--trust-type-annotations,--trust-primitives,--dump-info]
''');
  }

  void _generateIndexHtml() {
    _addFile('web/index.html', '''
<!doctype html>
<html>
  <title>Generated app: ${_genSpec.name}</title>
<body>
  <button id="createBtn">Create</button>
  <button id="destroyBtn">Destroy</button>
  <${_genSpec.rootComponent.name}>
    Loading...
  </${_genSpec.rootComponent.name}>

  <script type="text/javascript">
    console.timeStamp('>>> pre-script');
  </script>
  <script src="index.dart" type="application/dart"></script>
  <script src="packages/browser/dart.js" type="text/javascript"></script>
</body>
</html>
''');
  }

  void _generateIndexDart(Iterable<String> components) {
    _addFile('web/index.dart', '''
library ${_genSpec.name};

import 'dart:html';
import 'package:angular2/bootstrap.dart';
import 'package:${_genSpec.name}/${_genSpec.rootComponent.name}.dart';

main() async {
  window.console.time('bootstrap');
  var componentRef = await bootstrap(${_genSpec.rootComponent.name});
  window.console.timeEnd('bootstrap');
  var createBtn = querySelector('#createBtn');
  createBtn.onClick.listen( (e) {
    window.console.time('create');
    componentRef.instance.branch0 = true;
    componentRef.hostView.changeDetectorRef.detectChanges();
    window.console.timeEnd('create');
  });
  var destroyBtn = querySelector('#destroyBtn');
  destroyBtn.onClick.listen( (e) {
    window.console.time('destroy');
    componentRef.instance.branch0 = false;
    componentRef.hostView.changeDetectorRef.detectChanges();
    window.console.timeEnd('destroy');
  });

}

''');
  }

  void _generateComponentFiles(ComponentGenSpec compSpec) {
    _generateComponentDartFile(compSpec);
    _generateComponentTemplateFile(compSpec);
  }

  void _generateComponentDartFile(ComponentGenSpec compSpec) {
    final directiveImports = <String>[];
    final directives = <String>['NgIf', 'NgFor'];
    int totalProps = 0;
    int totalTextProps = 0;
    compSpec.template
      .map((NodeInstanceGenSpec nodeSpec) {
        totalProps += nodeSpec.propertyBindingCount;
        totalTextProps += nodeSpec.textBindingCount;
        return nodeSpec;
      })
      .where((NodeInstanceGenSpec nodeSpec) => nodeSpec.ref is ComponentGenSpec)
      .forEach((NodeInstanceGenSpec nodeSpec) {
        final childComponent = nodeSpec.nodeName;
        directives.add(childComponent);
        directiveImports.add("import '${childComponent}.dart';\n");
      });

    final props = new StringBuffer('\n');
    props.write(new List.generate(totalProps, (i) => '  var prop${i};')
        .join('\n'));

    final textProps = new StringBuffer('\n');
    textProps.write(new List.generate(totalTextProps, (i) => '  var text${i} = "val${random.nextInt(1000)}";')
        .join('\n'));

    final branchProps = new StringBuffer();
    int i = 0;
    compSpec.template.forEach((NodeInstanceGenSpec nodeSpec) {
      if (nodeSpec.branchSpec != null) {
        branchProps.write('  var branch${i++} = ${i == 1};');
      }
    });

    _addFile('lib/${compSpec.name}.dart', '''
library ${_genSpec.name}.${compSpec.name};

import 'package:angular2/angular2.dart';
${directiveImports.join('')}

@Component(
  selector: '${compSpec.name}'
)
@View(
  templateUrl: '${compSpec.name}.html'
${directives.isNotEmpty ? '  , directives: const ${directives}' : ''}
)
class ${compSpec.name} {
${props}
${branchProps}
${textProps}
}
''');
  }

  void _generateComponentTemplateFile(ComponentGenSpec compSpec) {
    int branchIndex = 0;
    int propIdx = 0;
    int textIdx = 0;
    var template = compSpec.template.map((NodeInstanceGenSpec nodeSpec) {
      final bindings = new StringBuffer();

      if (nodeSpec.propertyBindingCount > 0) {
        bindings.write(' ');
        bindings.write(new List.generate(nodeSpec.propertyBindingCount, (i) => '[prop${i}]="prop${i}"')
            .join(' '));
      }
      final branch = new StringBuffer();
      if (nodeSpec.branchSpec is IfBranchSpec) {
        IfBranchSpec ifBranch = nodeSpec.branchSpec;
        branch.write(' *ngIf="branch${branchIndex++}"');
      } else if (nodeSpec.branchSpec is RepeatBranchSpec) {
        RepeatBranchSpec repeatBranch = nodeSpec.branchSpec;
        branch.write(' *ngFor="#item of branch${branchIndex++}"');
      }

      final textBindings = new List.generate(nodeSpec.textBindingCount, (_) {
        return '{{text${textIdx++}}}';
      }).join();
      return '<${nodeSpec.nodeName}${bindings}${branch}>${textBindings}</${nodeSpec.nodeName}>' +
             '<${nodeSpec.nodeName}${bindings}${branch}>${textBindings}</${nodeSpec.nodeName}>';
    }).join('\n');
    _addFile('lib/${compSpec.name}.html', template);
  }

  void _generatePrecompiledTemplateFile(ComponentGenSpec compSpec) {
    int branchIndex = 0;
    final buf = new StringBuffer();

    List<String> directiveImports = [];
    compSpec.template
        .where((node) => node.ref is ComponentGenSpec)
        .map((node) => node.nodeName)
        .forEach(directiveImports.add);

    buf.write('''
library ${compSpec.name}.precompiled.template;

import 'package:angular2/angular2.dart';
import 'package:angular2/src/core/compiler/template_factory.dart' as _tf_;
${directiveImports.map((d) => "import '${d}.dart';").join('\n')}

const styles = const <String>[];

final commands = <TemplateCmd>[
''');

    int protoViewIndex = 1;
    compSpec.template.forEach((NodeInstanceGenSpec nodeSpec) {
      bool isBound =
          nodeSpec.branchSpec != null ||
          nodeSpec.ref is ComponentGenSpec ||
          nodeSpec.propertyBindingCount > 0 ||
          nodeSpec.textBindingCount > 0;

      final isComponent = nodeSpec.ref is ComponentGenSpec;
      final directives = <String>[];
      String templateDirective = null;
      if (nodeSpec.branchSpec is IfBranchSpec) {
        templateDirective = 'NgIf';
      } else if (nodeSpec.branchSpec is RepeatBranchSpec) {
        templateDirective = 'NgFor';
      }
      if (isComponent) {
        directives.add(nodeSpec.nodeName);
      }

      if (templateDirective != null) {
        buf.write("    _tf_.et('${compSpec.name}_embedded_${protoViewIndex++}', null, null, ${templateDirective}, false, null, [");
      }

      var endCommand;
      // Begin element
      buf.write("  _tf_.");
      if (isComponent) {
        buf.write("bc('${nodeSpec.nodeName}_comp_0', '${nodeSpec.nodeName}', null, null, null, ${directives}, false, null),");
        endCommand = 'ec';
      } else {
        if (isBound) {
          buf.write("bbe");
        } else {
          buf.write("be");
        }
        buf.write("('${nodeSpec.nodeName}', null, null, null, ${directives}, null),");
        endCommand = 'ee';
      }
      if (nodeSpec.textBindingCount > 0) {
        buf.write("    _tf_.btt(null),");
      }
      buf.writeln('  _tf_.${endCommand}(),');
      if (templateDirective != null) {
        buf.writeln(']),');
      }

    });

    buf.writeln('];');

    _addFile('lib/${compSpec.name}.precompiled.dart', buf.toString());
  }
}
