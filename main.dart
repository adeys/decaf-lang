import 'dart:io';

import 'src/error/error_reporter.dart';
import 'src/lexer/lexer.dart';
import 'src/parser/parser.dart';

Object run(String program) {
  try {
    Lexer lexer = new Lexer(program);

    var tokens = lexer.tokenize();
    Parser parser = new Parser(tokens);

    return parser.parse(); 
  } catch (e) {
    ErrorReporter.report(e);
    return null;
  }
}

void runPrompt() {
  print('Decaf REPL v0.1');
  print('Hit Ctrl+C to exit\n');

  while (true) {
    stdout.write('decaf > ');
    String line = stdin.readLineSync();
    
    print(run(line));
  }
}

void runFile(String filename) {
  File file = new File(filename);

  if (!file.existsSync()) {
    print('File $filename does not exist.');
    exit(60);
  }

  var result = run(file.readAsStringSync());
  print(result);
}

void main(List<String> args) {
  if (args.length > 1) {
    print('Usage : decaf [file]');
    exit(1);
  } else if (args.length == 1) {
    runFile(args[0]);
  } else {
    runPrompt();
  }
}