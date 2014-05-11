# RedHuntingHat - simple testsuites
# (C) 2014 Jostein Berre Eliassen
# Released under the MIT license.
# Available at https://github.com/jbe/RedHuntingHat

import
  strutils, tables, terminal

type
  TAssertion* = tuple
    desc:  string
    ast_str:    string
    filename:   string
    lineno:     int
    passed:     bool

  PTestGroup* = ref TTestGroup
  TTestGroup* = tuple
    unique_name, short_name:        string
    dbg:                            seq[string]
    assertions:                     seq[TAssertion]
    children:                       seq[PTestGroup]
    fail_count:                     int
    subtree_fail_count:             int
    subtree_assertion_count:        int

  TReportStyle* = enum st_normal, st_header, st_success, st_notice,
    st_failure, st_extended, st_todo

var
  group_stack                   = newSeq[PTestGroup]() # used while nesting groups
  is_in_exception_assertion     = false
  suites                        = initTable[string, PTestGroup]() # unique names

proc cur_scope(): PTestGroup =
  return group_stack[len(group_stack) - 1]

proc is_in_a_scope(): bool = len(group_stack) > 0

iterator levels(path: string): string =
  if contains(path, '/'):
    var n_acc = ""
    for n in split(path, '/'):
      n_acc &= n
      yield(n_acc)
      n_acc &= "/"
  else:
    yield path

iterator levels_reverse(path: string): string =
  if contains(path, '/'):
    var tokens = split(path, '/')
    var n_acc = ""
    for i in 1 .. len(tokens):
      n_acc = tokens[len(tokens) - i] & n_acc
      yield(n_acc)
      n_acc = "/" & n_acc
  else:
    yield path

proc bottom_level_of(path: string): string =
  if contains(path, '/'):
    return substr(path, rfind(path, "/")+1, len(path)-1)
  else: return path

proc parent_of(path: string): string =
  return substr(path, 0, rfind(path, "/") - 1)

proc new_group(name: string): PTestGroup =
  result              = new(TTestGroup)
  result.unique_name  = name
  result.short_name   = bottom_level_of(name)
  result.assertions   = newSeq[TAssertion]()
  result.children     = newSeq[PTestGroup]()
  suites[name]        = result

proc scope_stem(): string =
  if is_in_a_scope(): return cur_scope().unique_name & "/"
  else: return ""


proc get_or_create_group(name: string): PTestGroup =
  if suites[name] != nil: return suites[name]
  else:
    result = new_group(name)
    if contains(name, '/'):
      add(suites[parent_of(name)].children, result)

template test*(name: string, code: stmt): stmt =
  if is_in_exception_assertion:
    quit("groups are not allowed inside assert_raises")
  var
    grp: PTestGroup
    stem = scope_stem()
  for n in levels(name):
    grp = get_or_create_group(stem & n)
    add(group_stack, grp)
  code
  for n in levels_reverse(name):
    discard pop(group_stack)
    if is_in_a_scope():
      cur_scope().subtree_assertion_count += grp.subtree_assertion_count
      cur_scope().subtree_assertion_count += len(grp.assertions)
      cur_scope().subtree_fail_count += grp.subtree_fail_count
      cur_scope().subtree_fail_count += grp.fail_count


template req*(a: expr, desc="") =
  if not is_in_a_scope():
    quit("requirements are only allowed inside test suites")
  if is_in_exception_assertion:
    quit("requirements are not allowed inside req_exception blocks")
  let pos = instantiationInfo()
  var did_pass: bool
  did_pass = a
  add(cur_scope().assertions, (desc, "req " & a.astToStr(), pos.filename, pos.line, did_pass))
  if not did_pass:
    cur_scope().fail_count += 1

template req_exception*(excptn: typedesc, code: stmt): stmt =
  let pos = instantiationInfo()
  var raised_error = false
  is_in_exception_assertion = true
  try: code
  except excptn: raised_error = true
  is_in_exception_assertion = false
  add(cur_scope().assertions, ("should raise " & excptn.astToStr(), "see tests", pos.filename, pos.line, raised_error))
  if not raised_error:
    cur_scope().fail_count += 1

template dbg*(msg: varargs[string]) =
  if not is_in_a_scope():
    quit("dbg comments are only allowed inside test suites")
  if cur_scope().dbg.isNil: cur_scope().dbg = newSeq[string]()

  add(cur_scope().dbg, msg.join())


# Report printer:


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
    of st_notice:     WriteColored(str, fgYellow, {styleDim})
    of st_failure:    WriteColored(str, fgRed)
    of st_extended:   WriteStyled(str, {styleDim})
    of st_todo:       WriteColored(str, fgCyan, {styleDim})

proc show_fail_list(grp: PTestGroup) =
  add(group_stack, grp)

  if grp.fail_count > 0:
    #let name_str = map(group_stack, proc(x:PTestGroup): string = x.short_name).join("/")
    say(st_failure, "  ", grp.unique_name, ": \n")

    for s in grp.assertions:
      if not s.passed:
        say(st_normal, "    ", s.filename, "(", $s.lineno, "): ", s.desc)
        say(st_extended, " (", s.ast_str, ")\n")
    if not grp.dbg.isNil:
      for s in grp.dbg:
         say(st_notice, "    + ")
         say(st_extended, s, "\n")
      say(st_extended, "\n")
    echo("")

  for i in 0 .. <len(grp.children): show_fail_list(grp.children[i])
  discard pop(group_stack)

proc show_result_tree(grp: PTestGroup) =
  for i in 0 .. len(group_stack): write(stdout, "  ")

  say(st_normal, grp.short_name, ": ")
  say(st_extended, "(", $(grp.subtree_assertion_count + len(grp.assertions)), ") ")

  if grp.fail_count == 0:

    if (len(grp.assertions) > 0) or (grp.subtree_fail_count == 0 and len(grp.children) > 0):
      say(st_success, "ok")
    elif len(grp.children) == 0:
      say(st_todo, "# TODO")
  else:
    say(st_failure, $grp.fail_count, " fail")

  # say(st_extended, " ", $grp.subtree_assertion_count, " subtree")

  say(st_normal, "\n")

  add(group_stack, grp)
  if grp.subtree_fail_count > 0:
    for i in 0 .. <len(grp.children): show_result_tree(grp.children[i])
  discard pop(group_stack)

proc print_results*(names: varargs[string]) =
  for name in names:

    if suites[name] == nil: raise newException(ESynch,
      "invalid test suite name: " & name)
    echo ""
    let total_fail_count = suites[name].subtree_fail_count + suites[name].fail_count
    if total_fail_count > 0:
      say(st_failure, "  ", $total_fail_count, " requirements failed.")
    else:
      say(st_success, "  All requirements passed.")
    let total_assertion_count = suites[name].subtree_assertion_count + len(suites[name].assertions)
    #say(st_normal, "\n", $total_assertion_count, " total")
    echo "\n"
    #say(st_notice, "  Suites:\n\n")
    show_result_tree(suites[name])
    #echo ""
    #say(st_header, "Failures:")
    echo "\n"
    show_fail_list(suites[name])
    echo ""


when isMainModule:

  proc raise_esynch() = raise newException(ESynch, "yo")

  test("core/nimrod"):
    test("the huntsman"):
      test("should be sane"):
        req(true == true,   "false is false")
        req(false == false, "true is true")
        req_exception(ESynch):
          raise_esynch()
      test("should be insane"):
        req(true == false,  "true is false")
        req(1 == 2,         "one is two")
    test("the king"):
      test("should be powerful"):
        discard
      test("should wear a crown"):
        dbg("value of crown before req: gold")
        req("nimrod wears" == "crown", "all strings should be equal just because")
        dbg("value of crown after req: lead")

  print_results("core")

