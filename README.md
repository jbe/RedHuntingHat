
RedHuntingHat
=====

**Simple Nimrod test suites**

---

This library is a quick hack (but one that works well for me), that I use to create test suites for Nimrod projects than span several files. Right now, it only has one report printer; which produces ANSI colored terminal output. It is not in Babel yet, so you must download `RedHuntingHat.nim` if you want to use it.

Some sample output:

![Picture of formatted test output](http://i.imgur.com/3pAOgnJ.png)

In RHH, all tests and suites reside in a global name space. Suites can have child suites, and tests can be defined from any file. Any subtree of test suites can be easily printed, and it is easy to add debug notes to parts of the tree at run time. These notes are suite local, and will be shown when requirements fail.


**API:**

 template                               | Usage                         | Example
 -------------------------------------- |------------------------------ | ------------------------------
 `test(name: string)`                   | Define a test suite           | `test("linkedlist"): ..`
 `req(assertion: expr, desc="")`        | Add a requirement(assertion)  | `req(1 == 1)`
                                        |                               | `req(1 == 1, "one is one")`
 `req_exception(kind: typedesc)`        | Require that some statement raises an exception of some kind | `req_exception(EOverflow): ..`
 `dbg(msgs: varargs[string])`           | Adds a debug message to the current suite, that will be shown when one of its requirements fail. Useful for inspecting variables | `dbg("value of x: ", $x)`


---

© 2014 Jostein Berre Eliassen. Released under the MIT license. See LICENSE.txt.
