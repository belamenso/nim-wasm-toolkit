import
  options, streams, sugar, sequtils, endians, strutils

import print

type
  Version = int

  CustomSection = object
    name: string
    len: uint32

  Limits = object
    min: uint32
    max: Option[uint32]
  
  TypeIdx = uint32
  FuncIdx = uint32
  TableIdx = uint32
  MemIdx = uint32
  GlobalIdx = uint32
  LocalIdx = uint32
  LabelIdx = uint32

  Memarg = tuple
    align: uint32
    offset: uint32
  
  Value = enum
    i32, i64, f32, f64

  EmpryResult = enum empryResult # TODO
  Result = Value | EmpryResult

  InstructionKind = enum
    unreachable, nop, blockI, loop, ifI, br, br_l, br_table, returnI,
    call, call_indirect, drop, select, local_get, local_set, local_tee,
    global_set, global_get,

    i32_load,
    i64_load,
    f32_load,
    f64_load,

    i32_load8_s,
    i32_load8_u,
    i32_load16_s,
    i32_load16_u,

    i64_load8_s,
    i64_load8_u,
    i64_load16_s,
    i64_load16_u,
    i64_load32_s,
    i64_load32_u,

    i32_store,
    i64_store,
    f32_store,
    f64_store,

    i32_store8,
    i32_store16,
    i64_store8,
    i64_store16,
    i64_store32,
    memory_size,
    memory_grow,

    i32_const,
    i64_const,
    f32_const,
    f64_const,

    i32_eqz,
    i32_eq,
    i32_ne,
    i32_lt_s,
    i32_lt_u,
    i32_gt_s,
    i32_gt_u,
    i32_le_s,
    i32_le_u,
    i32_ge_s,
    i32_ge_u,
    i64_eqz,
    i64_eq,
    i64_ne,
    i64_lt_s,
    i64_lt_u,
    i64_gt_s,
    i64_gt_u,
    i64_le_s,
    i64_le_u,
    i64_ge_s,
    i64_ge_u,
    f32_eq,
    f32_ne,
    f32_lt,
    f32_gt,
    f32_le,
    f32_ge,
    f64_eq,
    f64_ne,
    f64_lt,
    f64_gt,
    f64_le,
    f64_ge,
    i32_clz,
    i32_ctz,
    i32_popcnt,
    i32_add,
    i32_sub,
    i32_mul,
    i32_div_s,
    i32_div_u,
    i32_rem_s,
    i32_rem_u,
    i32_and,
    i32_or,
    i32_xor,
    i32_shl,
    i32_shr_s,
    i32_shr_u,
    i32_rotl,
    i32_rotr,
    i64_clz,
    i64_ctz,
    i64_popcnt,
    i64_add,
    i64_sub,
    i64_mul,
    i64_div_s,
    i64_div_u,
    i64_rem_s,
    i64_rem_u,
    i64_and,
    i64_or,
    i64_xor,
    i64_shl,
    i64_shr_s,
    i64_shr_u,
    i64_rotl,
    i64_rotr,
    f32_abs,
    f32_neg,
    f32_ceil,
    f32_floor,
    f32_trunc,
    f32_nearest,
    f32_sqrt,
    f32_add,
    f32_sub,
    f32_mul,
    f32_div,
    f32_min,
    f32_max,
    f32_copysign,
    f64_abs,
    f64_neg,
    f64_ceil,
    f64_floor,
    f64_trunc,
    f64_nearest,
    f64_sqrt,
    f64_add,
    f64_sub,
    f64_mul,
    f64_div,
    f64_min,
    f64_max,
    f64_copysign,
    i32_wrap_i64,
    i32_trunc_f32_s,
    i32_trunc_f32_u,
    i32_trunc_f64_s,
    i32_trunc_f64_u,
    i64_extend_i32_s,
    i64_extend_i32_u,
    i64_trunc_f32_s,
    i64_trunc_f32_u,
    i64_trunc_f64_s,
    i64_trunc_f64_u,
    f32_convert_i32_s,
    f32_convert_i32_u,
    f32_convert_i64_s,
    f32_convert_i64_u,
    f32_demote_f64,
    f64_convert_i32_s,
    f64_convert_i32_u,
    f64_convert_i64_s,
    f64_convert_i64_u,
    f64_promote_f32,
    i32_reinterpret_f32,
    i64_reinterpret_f64,
    f32_reinterpret_i32,
    f64_reinterpret_i64

  #Instruction = object
    #case kind: 

  Function = object
    domain: seq[Value]
    image: seq[Value]

  Memory = Limits

  Table = Limits

  Mut = enum
    constMut, varMut

  Global = object
    mut: Mut
    valtype: Value

  External = Function | Table | Memory | Global

  TypeSection = seq[Function]

  TableSection = seq[Table]

  ImportDescriptionKind = enum
    typeIdx, tableType, memType, globalType

  ImportDescription = object
    case kind: ImportDescriptionKind
    of typeIdx: typeIdx: uint32
    of tableType: tableType: Table
    of memType: memType: Memory
    of globalType: globalType: Global

  Import = object
    module: string
    name: string
    importdesc: ImportDescription

  ImportSection = seq[Import]

  FunctionSection = seq[uint32]

  MemorySection = seq[Memory]

  ExportDescriptionKind = enum
    funcIdx=0, tableIdx=1, memIdx=2, globalIdx=3

  Export = object
    name: string
    idxType: ExportDescriptionKind
    idx: uint32

  ExportSection = seq[Export]

  StartSection = Option[uint32]

  Module = object
    version: Version
    typeSection: Option[TypeSection]
    importSection: Option[ImportSection]
    functionSection: Option[FunctionSection]
    tableSection: Option[TableSection]
    memorySection: Option[MemorySection]
    exportSection: Option[ExportSection]
    startSection: StartSection
    customSections: seq[CustomSection]

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

proc parseLeb128U32(): uint32 =
  if b shr 7 == 0:
    result = uint32(b) # TODO
    next()
  else:
    result = uint32(b) - (1 shl 7)
    next()
    result += uint32(1 shl 7) * parseLeb128U32()

proc parseU32(): int32 = # TODO ???
  let s = getBytes(4)
  littleEndian32(addr result, unsafeAddr s[0])

proc parseCustomSection(): CustomSection =
  echo "CUUUUUUSSSTTTTOOOMMMM"
  skip @[0]
  let size = parseLeb128U32()
  let strSize = parseLeb128U32()
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

proc parseVector[T](parseElement: proc(): T): seq[T] =
  let size = parseLeb128U32()
  echo ">>>>>>>>>>>>>>>>>>>>>> size is ", $size
  for i in 1..size:
    result.add parseElement()

proc parseValueType(): Value =
  case b:
  of 0x7f: result = i32; next()
  of 0x7e: result = i64; next()
  of 0x7d: result = f32; next()
  of 0x7c: result = f64; next()
  else: assertP false, "Invalid value type: " & $b

proc parseResultType(): Result =
  if b in {0x7f, 0x7e, 0x7d, 0x7c}:
    parseValueType()
  else:
    assertP b == 0x40, "invlid result byte"
    return EmpryResult

proc parseFunctionType(): Function =
  skip @[0x60]
  Function(
    domain: parseVector(parseValueType),
    image: parseVector(parseValueType))

proc parseTypeSection(): Option[TypeSection] =
  if b != 1: return

  skip @[1]
  let size = parseLeb128U32()
  some parseVector(parseFunctionType)

proc parseName(): string =
  parseVector(proc(): char =
    result = chr(b)
    next()).join("")

proc parseIdx: uint32 = parseLeb128U32()

proc parseLimits(): Limits =
  case b:
  of 0x00: # TODO
    result = Limits( min: parseLeb128U32(), max: none(uint32) )
  of 0x01:
    result = Limits( min: parseLeb128U32(), max: some(parseLeb128U32()) )
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
  let size = parseLeb128U32()
  some parseVector(parseImport)

proc parseFunctionSection(): Option[FunctionSection] =
  if b != 3: return

  skip @[3]
  let size = parseLeb128U32()

  let indices = parseVector(parseIdx)
  if indices.len != 0:
    result = some indices
  echo "size was ", $size, " and indices are ", repr(indices)

proc parseTableSection(): Option[TableSection] =
  if b != 4: return
  skip @[4]
  let size = parseLeb128U32()
  
  some parseVector(parseTableType)

proc parseMemorySection: Option[MemorySection] =
  if b != 5: return
  skip @[5]
  let size = parseLeb128U32()
  
  some parseVector(parseMemType)

proc parseExport(): Export =
  result.name = parseName()
  assertP b in {0,1,2,4}, "Invalid Export Byte"
  result.idxType = ExportDescriptionKind(int(b))
  result.idx = parseLeb128U32()

proc parseExportSection(): Option[ExportSection] =
  if b != 7: return
  skip @[7]
  let size = parseLeb128U32()

  some parseVector(parseExport)

proc parseStartSection(): StartSection =
  if b != 8: return
  skip @[8]
  let size = parseLeb128U32()

  some parseLeb128U32()

proc parseModule(): Module =
  var customSections: seq[CustomSection]

  skip @[0]
  skip @['a','s','m'].map(c => c.ord)
  let v: Version = parseU32()

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
  # TODO expr -> global saection
  let exportSection = parseExportSection()
  customsections &= parseCustomSections()
  let startSection = parseStartSection()
  customsections &= parseCustomSections()
  # TODO expr -> element section
  # TODO expr -> code section
  # TODO expr -> data section

  Module(
    version: v,
    typeSection: typeSection,
    importSection: importSection,
    functionSection: functionSection,
    tableSection: tableSection,
    memorySection: memorySection,
    exportSection: exportSection,
    startSection: startSection,
    customSections: customSections,
  )

proc init() =
  fs = newFileStream("03.wasm")
  next()

init()
echo repr parseModule()

