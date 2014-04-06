
import strutils, tables, terminal
export tables

setForegroundColor(fgWhite)

type
  TTestAssertion = tuple
    desc:       string
    ast_str:    string
    filename:   string
    lineno:     int
    passed:     bool

  PTestGroup = ref TTestGroup
  TTestGroup = tuple
    name:                       string
    assertions:                 seq[TTestAssertion]
    children:                   seq[PTestGroup]
    fail_count:                 int
    subtree_fail_count:         int
    subtree_assertion_count:    int

  TReportStyle = enum st_normal, st_header, st_success, st_notice,
    st_failure, st_extended, st_todo

proc WriteColored(str: string, color: TForegroundColor, style={styleBright}) =
  setForegroundColor(color)
  WriteStyled(str, style)
  setForegroundColor(fgWhite)

proc say[T](style: TReportStyle, strs: varargs[T]) =
  for str in strs:
    case style:
    of st_normal:     write(stdout, str)
    of st_header:     WriteStyled(str, {styleBright})
    of st_success:    WriteColored(str, fgGreen)
    of st_notice:     WriteStyled(str, {styleUnderscore})
    of st_failure:    WriteColored(str, fgRed)
    of st_extended:   WriteStyled(str, {styleDim})
    of st_todo:       WriteColored(str, fgCyan, {styleDim})



var initialized {.threadvar.}: bool
var scope_stack {.threadvar.}: seq[PTestGroup]
var is_inside_exception_assertion {.threadvar.}: bool

var suites = initTable[string, PTestGroup]()

template cur_scope(): PTestGroup =
  scope_stack[len(scope_stack) - 1]

template group*(group_name: string, code: stmt): stmt =
  if is_inside_exception_assertion:
    quit("groups are not allowed inside assert_raises")
  var grp = new(TTestGroup)
  grp.name = group_name
  grp.assertions = newSeq[TTestAssertion]()
  grp.children = newSeq[PTestGroup]()
  if len(scope_stack) > 0: add(cur_scope.children, grp)
  add(scope_stack, grp)
  code
  var exited_scope = cur_scope
  discard pop(scope_stack)
  if len(scope_stack) > 0:
    cur_scope.subtree_assertion_count += exited_scope.subtree_assertion_count
    cur_scope.subtree_assertion_count += len(exited_scope.assertions)
    cur_scope.subtree_fail_count += exited_scope.subtree_fail_count
    cur_scope.subtree_fail_count += exited_scope.fail_count

template test_suite*(name: string, code: stmt) =
  if not initialized:
    scope_stack = newSeq[PTestGroup]()
    initialized = true
  group(name):
    code
    suites[name] = scope_stack[0]

proc show_fail_list(grp: PTestGroup) =
  add(scope_stack, grp)

  if grp.fail_count > 0:
    let name_str = map(scope_stack, proc(x:PTestGroup): string = x.name).join("/")
    say(st_failure, "  ", name_str, ": \n")

    for s in grp.assertions:
      if not s.passed:
        say(st_normal, "    ", s.filename, "(", $s.lineno, "): ", s.desc)
        say(st_extended, " (", s.ast_str, ")\n")
    echo("")

  for i in 0 .. <len(grp.children): show_fail_list(grp.children[i])
  discard pop(scope_stack)

proc show_result_tree(grp: PTestGroup) =
  for i in 0 .. len(scope_stack): write(stdout, "  ")

  say(st_normal, grp.name, ": ")

  if grp.fail_count == 0:
    if len(grp.assertions) > 0:
      say(st_success, "ok")
    elif len(grp.children) == 0:
      say(st_todo, "todo")
  else:
    say(st_failure, $grp.fail_count, " fail")

  say(st_normal, "\n")

  add(scope_stack, grp)
  for i in 0 .. <len(grp.children): show_result_tree(grp.children[i])
  discard pop(scope_stack)

proc run_suite*(names: varargs[string]) =
  for name in names:

    if suites[name] == nil: raise newException(ESynch,
      "invalid test suite name: " & name)
    echo ""
    #say(st_header, "Test results (", name, ")")
    #echo "\n"
    let total_fail_count = suites[name].subtree_fail_count + suites[name].fail_count
    if total_fail_count > 0:
      say(st_failure, $total_fail_count, " tests failed.")
    else:
      say(st_success, $total_fail_count, " All tests passed")
    let total_assertion_count = suites[name].subtree_assertion_count + len(suites[name].assertions)
    say(st_normal, "\n", $total_assertion_count, " total")
    echo "\n"
    show_result_tree(suites[name])
    #echo ""
    #say(st_header, "Failures:")
    echo "\n"
    show_fail_list(suites[name])
    echo ""

template require*(a: expr, desc="") =
  if is_inside_exception_assertion:
    quit("requirements are not allowed inside require_exception")
  let pos = instantiationInfo()
  var did_pass: bool
  did_pass = a
  add(cur_scope.assertions, (desc, "assert " & a.astToStr(), pos.filename, pos.line, did_pass))
  if not did_pass:
    cur_scope.fail_count += 1

template require_exception*(excptn, code: stmt): stmt =
  let pos = instantiationInfo()
  var raised_error: bool
  is_inside_exception_assertion = true
  try: code
  except excptn: raised_error = true
  is_inside_exception_assertion = false
  add(cur_scope.assertions, ("should raise " & excptn.astToStr(), "see tests", pos.filename, pos.line, raised_error))


when isMainModule:

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

