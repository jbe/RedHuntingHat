
RedHuntingHat
=====

**Simple Nimrod test suites**

---

This library is a quick hack (but one that works well for me), that I use to create test suites for my Nimrod projects. Right now, it only has one report printer; which produces ANSI colored terminal output. It is not in Babel, so you must download `RedHuntingHat.nim` if you want to use it.

Here is some sample output:

![Picture of formatted test output](http://i.imgur.com/sfsoxfw.png)

**Features:**

- Very simple syntax
- Lets you define named test suites
- A named test suite is a tree of named test suites
- Assertions and suites can be added to any subtree from any file
- Any subtree of suites can be easily printed
- Easy to iterate over test results if needed

**API:**

 template                               | Usage                         | Example
 -------------------------------------- |------------------------------ | ------------------------------
 `test(name: string)`                   | Define a test suite           | `test("linkedlist"): ..`
 `req(assertion: expr, desc="")`        | Add a requirement(assertion)  | `req(1 == 1)`
                                        |                               | `req(1 == 1, "one is one")`
 `req_exception(kind: typedesc)`        | Require that some statement raises an exception of some kind | `req_exception(EOverflow): ..`


---

© 2014 Jostein Berre Eliassen. Released under the MIT license. See LICENSE.txt.
