import 'dart:io';

import 'package:dlox/dlox.dart';

void main(List<String> args) {
  Set<String> testPaths = args.toSet();
  print("Args: $args");
  List<File?> testFiles = (Directory(Platform.operatingSystem == "windows"
          ? ".\\test_cases"
          : "./test_cases")
      .listSync()
      .map((e) => e is File ? e : null)
      .toList()
    ..retainWhere((e) =>
        e is File && (args.isEmpty || (() => testPaths.contains(e.path))())));

  List<(String, String)> testCases = testFiles
      .map((e) =>
          (e!.path.split("/").last.split(".dlox").first, e.readAsStringSync()))
      .toList();

  var (parsePass, parseFail) = parseTest(testCases);
  print("Parse test ($parsePass/$parseFail)");
  if (parsePass == 0) {
    print("All parse tests failed");
    return;
  }

  var (prettyPrintPass, prettyPrintFail) = prettyPrintTest(testCases);
  print("Pretty print test ($prettyPrintPass/$prettyPrintFail)");
}

(int, int) parseTest(List<(String, String)> testCases) {
  int passCount = 0, failCount = 0;
  print("Running parse test");
  for (var (testName, testContent) in testCases) {
    print("Running $testName");
    parse(testContent);
    if (hadError) {
      hadError = false;
      print("Parse test failed for:\n$testContent");
      failCount++;
    } else {
      passCount++;
    }
  }
  return (passCount, failCount);
}

(int, int) prettyPrintTest(List<(String, String)> testCases) {
  int passCount = 0, failCount = 0;
  print("Running pretty print test");
  for (var (testName, testContent) in testCases) {
    bool pass = true;
    print("Running $testName");
    var (firstTokens, firstNodes!) = parse(testContent);
    String prettyCode = format(testContent);
    var (secondTokens, secondNodes!) = parse(prettyCode);
    if (firstTokens.length != secondTokens.length) {
      print(
          "First pass token count ${firstTokens.length} != Second pass token count ${secondTokens.length}");
      pass = false;
    }

    if (firstNodes.length != secondNodes.length) {
      print(
          "First pass node count ${firstNodes.length} != Second pass node count ${secondNodes.length}");
      print("First: $firstNodes");
      print("Second: $secondNodes");
      pass = false;
    }
    if (pass) {
      passCount++;
    } else {
      print("From:\n$testContent");
      print("To:\n$prettyCode");
      failCount++;
    }

    print(pass ? "Success" : "********\nFAILED\n********");
  }
  return (passCount, failCount);
}
