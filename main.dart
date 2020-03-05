import 'dart:io';

import 'src/error/error.dart';
import 'src/lexer/lexer.dart';

Object run(String program) {
  try {
    Lexer lexer = new Lexer(program);

    return lexer.tokenize(); 
  } on SyntaxError catch (e) {
    print('[line ${e.line}] SyntaxError : ' + e.message);
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