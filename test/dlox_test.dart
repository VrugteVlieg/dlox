import 'dart:io';

import 'package:dlox/dlox.dart';

void main() {
  print(Directory.current.path);
  List<File?> testFiles = (Directory("./test_cases")
      .listSync()
      .map((e) => e is File ? e : null)
      .toList()
    ..retainWhere((e) => e is File));

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
    var (_, nodes) = parse(testContent);
    if (nodes == null) {
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
