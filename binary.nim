import
  options, streams, sugar, sequtils, endians, strutils

import
  types

var
  fs: FileStream
  eof = false
  b: uint8

proc next() =
  try:
    b = fs.readUint8()
    echo "B is ", $b
  except:
    b = 0
    eof = true

proc assertP(test: bool, str="") =
  if str.len != 0:
    doAssert test, str
  else:
    doAssert test

proc skip(bs: seq[int]) =
  for byte in bs:
    assertP b == uint8(byte)
    next()

proc getBytes(n: uint): seq[uint8] =
  for i in 1..n:
    result.add b
    next()

proc parse_unsigned[T](): T =
  if (b shr 7) == 0:
    result = T(b)
    next()
  else:
    result = T(b) - (1 shl 7)
    next()
    result += T(1 shl 7) * parse_unsigned[T]()

proc parse_signed[T](): T =
  let lb = T(b)
  next()
  if lb < (1 shl 7):
    if lb < (1 shl 6):
      lb
    else:
      lb - (1 shl 7)
  else:
    lb - (1 shl 7) + (1 shl 7) * parse_signed[T]()

proc parse_u32: uint32 = parse_unsigned[uint32]()
proc parse_u64: uint64 = parse_unsigned[uint64]()
proc parse_i32: int32 = parse_signed[int32]()
proc parse_i64: int64 = parse_signed[int64]()

proc parseVector[T](parseElement: proc(): T): seq[T] =
  let size = parse_u32()
  for i in 1..size:
    result.add parseElement()

proc parseValueType(): Value =
  case b:
  of 0x7f: result = i32; next()
  of 0x7e: result = i64; next()
  of 0x7d: result = f32; next()
  of 0x7c: result = f64; next()
  else: assertP false, "Invalid value type: " & $b

proc parseResultType: Result =
  if b in {0x7f, 0x7e, 0x7d, 0x7c}:
    some parseValueType()
  else:
    assertP b == 0x40, "invlid result byte"
    none(Value)

proc parseBlockType: Block = parseResultType()

proc parseVersion: int =
  let s = getBytes(4)
  for i in countdown(3, 0):
    result = (1 shl 8) * result + int(s[i])

proc parseIdx: uint32 = parse_u32()

proc parseMemarg: Memarg = (parse_u32(), parse_u32())

proc parseInstr: Instr =
  let bi = InstructionKind(b)
  next()

  result = Instr(kind: bi)

  case bi:
  of InstructionKind(0x45)..InstructionKind(0xbf), drop, select, unreachable, nop, returnI:
    return
  of blockI, loop:
    result.blockType = parseBlockType()
    var instructions: seq[Instr]
    while b != 0x0b:
      result.instructions.add parseInstr()
    skip @[0x0b]
  of ifI:
    result.blockType = parseBlockType()
    while not b in {0x0b, 0x05}:
      result.ifTrue.add parseInstr()
    if b == 0x0b:
      skip @[0x0b]
      return
    skip @[0x05]
    while b != 0x0b:
      result.ifFalse.add parseInstr()
    skip @[0x0b]
  of br, br_if:
    result.idx = parse_u32()
  of br_table:
    result.labels = parseVector(parseIdx)
    result.labelidx = parseIdx()
  of call:
    result.funcidx = parse_u32()
  of call_indirect:
    result.typeidx = parse_u32()
    skip @[0x00]
  of local_get, local_set, local_tee:
    result.localidx = parse_u32()
  of global_get, global_set:
    result.globalidx = parse_u32()
  of InstructionKind(0x28)..InstructionKind(0x3e):
    result.memarg = parseMemarg()
  of memory_size, memory_grow:
    skip @[0x00]
  of i32_const:
    result.i32_val = parse_i32()
  of i64_const:
    result.i64_val = parse_i64()
  of f32_const:
    assert false # TODO
  of f64_const:
    assert false # TODO

proc parseExpression: Expr =
  while b != 0x0b:
    result.add parseInstr()
  skip @[0x0b]

proc parseCustomSection(): CustomSection =
  skip @[0]
  let size = parse_u32()
  let strSize = parse_u32()
  assertP strSize <= size
  var name = newString(strSize)
  for i in 1..strSize:
    name[i-1] = chr(b)
    next()
  result = CustomSection( name: name, len: size )
  discard getBytes(uint(size - strSize))
  echo "END CUSTOM with size, strSize, name = ", $size, " ", $strSize, " ", name

proc parseCustomSections(): seq[CustomSection] =
  while not eof and b == 0:
    result.add parseCustomSection()

proc parseFunctionType(): FunctionT =
  skip @[0x60]
  FunctionT(
    domain: parseVector(parseValueType),
    image: parseVector(parseValueType))

proc parseTypeSection(): Option[TypeSection] =
  if b != 1: return

  skip @[1]
  let size = parse_u32()
  some parseVector(parseFunctionType)

proc parseName(): string =
  parseVector(proc(): char =
    result = chr(b)
    next()).join("")

proc parseLimits(): Limits =
  case b:
  of 0x00: # TODO
    result = Limits( min: parse_u32(), max: none(uint32) )
  of 0x01:
    result = Limits( min: parse_u32(), max: some(parse_u32()) )
  else:
    assertP false, "Invalid limit byte"

proc parseTableType(): Table =
  skip @[0x70]
  parseLimits()

proc parseMemType(): Memory =
  parseLimits()

proc parseMut(): Mut =
  case b:
  of 0x00: result = constMut
  of 0x01: result = varMut
  else: assertP false, "Invalid mut byte"

proc parseGlobalType(): Global =
  let
    v = parseValueType()
    m = parseMut()
  Global( mut: m, valtype: v )

proc parseImport():Import =
  let
    module = parseName()
    name = parseName()
  var importdesc: ImportDescription
  case b:
  of 0x00: next(); importdesc = ImportDescription(kind: typeIdx, typeIdx: parseIdx())
  of 0x01: next(); importdesc = ImportDescription(kind: tableType, tableType: parseTableType())
  of 0x02: next(); importdesc = ImportDescription(kind: memType, memType: parseMemType())
  of 0x03: next(); importdesc = ImportDescription(kind: globalType, globalType: parseGlobalType())
  else: assertP false, "Incorrect import byte"
  Import(
    module: module,
    name: name,
    importdesc: importdesc,
  )

proc parseImportSection(): Option[ImportSection] =
  if b != 2: return
  skip @[2]
  let size = parse_u32()
  some parseVector(parseImport)

proc parseFunctionSection(): Option[FunctionSection] =
  if b != 3: return

  skip @[3]
  let size = parse_u32()

  let indices = parseVector(parseIdx)
  if indices.len != 0:
    result = some indices
  echo "size was ", $size, " and indices are ", repr(indices)

proc parseTableSection(): Option[TableSection] =
  if b != 4: return
  skip @[4]
  let size = parse_u32()
  
  some parseVector(parseTableType)

proc parseMemorySection: Option[MemorySection] =
  if b != 5: return
  skip @[5]
  let size = parse_u32()
  
  some parseVector(parseMemType)

proc parseGlobalElement: GlobalElement =
  result.globaltype = parseGlobalType()
  result.expr = parseExpression()

proc parseGlobalSection: Option[GlobalSection] =
  if b != 6: return
  skip @[6]
  let size = parse_u32()
  
  some parseVector(parseGlobalElement)

proc parseExport(): Export =
  result.name = parseName()
  assertP b in {0,1,2,4}, "Invalid Export Byte"
  result.idxType = ExportDescriptionKind(int(b))
  next()
  result.idx = parse_u32()

proc parseExportSection(): Option[ExportSection] =
  if b != 7: return
  skip @[7]
  let size = parse_u32()

  some parseVector(parseExport)

proc parseStartSection: StartSection =
  if b != 8: return
  skip @[8]
  let size = parse_u32()

  some parse_u32()

proc parseElement: Element =
  result.idx = parse_u32()
  result.expr = parseExpression()
  result.init = parseVector(parseIdx)

proc parseElementSection: Option[ElementSection] =
  if b != 9: return
  skip @[9]
  let size = parse_u32()

  some parseVector(parseElement)

proc parseLocal: Local =
  result.n = parse_u32()
  result.valtype = parseValueType()

proc parseFunction: Function =
  result.locals = parseVector(parseLocal)
  result.expr = parseExpression()

proc parseCode: Code =
  result.size = parse_u32()
  result.code = parseFunction()

proc parseCodeSection: Option[CodeSection] =
  echo "CCCCCCOOOOOOOOODDDDDDDDDEEEEEEEEE"
  if b != 10:
    echo "wtd-------------------, b is ", $b
  if b != 10: return
  echo "CCCCCCOOOOOOOOODDDDDDDDDEEEEEEEEE"
  skip @[10]
  let size = parse_u32()

  some parseVector(parseCode)

proc parseData: Data =
  result.idx = parse_u32()
  result.expr = parseExpression()

  let n = parse_u32()
  result.init = getBytes(n)

proc parseDataSection: Option[DataSection] =
  if b != 11: return
  skip @[11]
  let size = parse_u32()

  some parseVector(parseData)

proc parseModule(): Module =
  var customSections: seq[CustomSection]

  skip @[0]
  skip @['a','s','m'].map(c => c.ord)
  let v: Version = parseVersion()

  customSections &= parseCustomSections()
  let typeSection  = parseTypeSection()
  customSections &= parseCustomSections()
  let importSection  = parseImportSection()
  customSections &= parseCustomSections()
  let functionSection  = parseFunctionSection()
  customSections &= parseCustomSections()
  let tableSection = parseTableSection()
  customSections &= parseCustomSections()
  let memorySection = parseMemorySection()
  customsections &= parseCustomSections()
  let globalSection = parseGlobalSection()
  customsections &= parseCustomSections()
  let exportSection = parseExportSection()
  customsections &= parseCustomSections()
  let startSection = parseStartSection()
  customsections &= parseCustomSections()
  let elementSection = parseElementSection()
  customsections &= parseCustomSections()
  let codeSection = parseCodeSection()
  customsections &= parseCustomSections()
  let dataSection = parseDataSection()
  customsections &= parseCustomSections()

  Module(
    version: v,
    typeSection: typeSection,
    importSection: importSection,
    functionSection: functionSection,
    tableSection: tableSection,
    memorySection: memorySection,
    globalSection: globalSection,
    exportSection: exportSection,
    startSection: startSection,
    elementSection: elementSection,
    codeSection: codeSection,
    dataSection: dataSection,
    customSections: customSections,
  )

proc init() =
  fs = newFileStream("03.wasm")
  next()

init()
echo repr parseModule()

