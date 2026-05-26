# dlox
 An implementation of the [Lox](https://craftinginterpreters.com/the-lox-language.html) programming language in [Dart](https://dart.dev/).

This implementation used [Crafting Interpreters](https://craftinginterpreters.com/contents.html) as a guide.

It includes a couple of features from the end of chapter challenges:

 1. Ternary operator (?) `print ? true "true" : "false;`
 2. Read builtin 
 ```
 // Declare variable and read into it
 var a;
 read a;

 // Or declare and assign in one step
 read var a;
 ```
 3. Lambda functions 
 ```
 fun thrice(fn) {
  for (var i = 1; i <= 3; i = i + 1) {
    fn(i);
  }
}

thrice(fun (a) {
  print a;
});
// "1".
// "2".
// "3".
 ```


 # Usage
 ## To enter a REPL simply run
 ```
 dart run                                                                     
 Building package executable... 
Built dlox:dlox.
> 
print "Hello World";
Hello World
>                                                           
 ```

 ## Execute a file
 ```
 dart run bin/dlox.dart run test/test_cases/hello_world.dlox
 Hello World
 ```

## Format a file and print to stdout

```
dart run bin/dlox.dart format test/test_cases/hello_world.dlox
print "Hello World";
```