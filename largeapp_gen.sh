dart ./bin/gen_scaffold_spec.dart -t 2 -d 4 -b 2 -c 1 > largeapp.spec
dart ./bin/gen_app.dart -i largeapp.spec -o build/largeapp1 -f ng2-dart
dart ./bin/gen_app.dart -i largeapp.spec -o build/largeapp2 -f ng2-dart
