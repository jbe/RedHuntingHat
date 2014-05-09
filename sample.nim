
import RedHuntingHat



proc raise_esynch() = raise newException(ESynch, "yo")

test("core/nimrod"):
  test("the huntsman"):
    test("should be sane"):
      req(true == true,   "true is true")
      req(false == false, "false is false")
      req_exception(ESynch):
        raise_esynch()
    test("should be insane"):
      req(true == false,  "true is false")
      req(1 == 2,         "one is two")

test("core/nimrod/the king"): # the tree of suites is implicitly merged.
  test("should be powerful"): # this way you can distribute tests across
    discard                   # more than one file.
  test("should wear a crown"):
    dbg("x before swizzling: 1237")
    req("crown" == "big", "this obviously fails")
    dbg("x after swizzling: 2344324")

test("core"):
  test("nimrod/the king"):
    test("should wear a crown"):
      req("crown" == "corona", "equal strings are equal when they are not equal")

print_results("core")

#print_results("core/nimrod/the huntsman/should be sane")

