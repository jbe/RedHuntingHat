
import RedHuntingHat


proc raise_esynch() = raise newException(ESynch, "yo")

test_suite("nimrod"):
  group("the huntsman"):
    group("should be sane"):
      require(true == true,   "false is false")
      require(false == false, "true is true")
      require_exception(ESynch):
        raise_esynch()
    group("should be insane"):
      require(true == false,  "true is false")
      require(1 == 2,         "one is two")
  group("the king"):
    group("should be powerful"):
      discard

run_suite("nimrod")

