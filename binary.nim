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

  Block = Result

  InstructionKind = enum
    unreachable = 0x00,
    nop = 0x01,
    blockI = 0x02,
    loop = 0x03,
    ifI = 0x04,
    br = 0x0c,
    br_if = 0x0d,
    br_table = 0x0e,
    returnI = 0x0f,
    call = 0x10,
    call_indirect = 0x11,

    drop = 0x1a,
    select = 0x1b,

    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,

    i32_load = 0x28,
    i64_load = 0x29,
    f32_load = 0x2a,
    f64_load = 0x2b,

    i32_load8_s = 0x2c,
    i32_load8_u = 0x2d,
    i32_load16_s = 0x2e,
    i32_load16_u = 0x2f,

    i64_load8_s = 0x30,
    i64_load8_u = 0x31,
    i64_load16_s = 0x32,
    i64_load16_u = 0x33,
    i64_load32_s = 0x34,
    i64_load32_u = 0x35,

    i32_store = 0x36,
    i64_store = 0x37,
    f32_store = 0x38,
    f64_store = 0x39,

    i32_store8 = 0x3a,
    i32_store16 = 0x3b,
    i64_store8 = 0x3c,
    i64_store16 = 0x3d,
    i64_store32 = 0x3e,
    memory_size = 0x3f,
    memory_grow = 0x40,

    i32_const = 0x41,
    i64_const = 0x42,
    f32_const = 0x43,
    f64_const = 0x44,

    # these have no immediate arguments
    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4a,
    i32_gt_u = 0x4b,
    i32_le_s = 0x4c,
    i32_le_u = 0x4d,
    i32_ge_s = 0x4e,
    i32_ge_u = 0x4f,
    i64_eqz = 0x50,
    i64_eq = 0x51,
    i64_ne = 0x52,
    i64_lt_s = 0x53,
    i64_lt_u = 0x54,
    i64_gt_s = 0x55,
    i64_gt_u = 0x56,
    i64_le_s = 0x57,
    i64_le_u = 0x58,
    i64_ge_s = 0x59,
    i64_ge_u = 0x5a,
    f32_eq = 0x5b,
    f32_ne = 0x5c,
    f32_lt = 0x5d,
    f32_gt = 0x5e,
    f32_le = 0x5f,
    f32_ge = 0x60,
    f64_eq = 0x61,
    f64_ne = 0x62,
    f64_lt = 0x63,
    f64_gt = 0x64,
    f64_le = 0x65,
    f64_ge = 0x66,
    i32_clz = 0x67,
    i32_ctz = 0x68,
    i32_popcnt = 0x69,
    i32_add = 0x6a,
    i32_sub = 0x6b,
    i32_mul = 0x6c,
    i32_div_s = 0x6d,
    i32_div_u = 0x6e,
    i32_rem_s = 0x6f,
    i32_rem_u = 0x70,
    i32_and = 0x71,
    i32_or = 0x72,
    i32_xor = 0x73,
    i32_shl = 0x74,
    i32_shr_s = 0x75,
    i32_shr_u = 0x76,
    i32_rotl = 0x77,
    i32_rotr = 0x78,
    i64_clz = 0x79,
    i64_ctz = 0x7a,
    i64_popcnt = 0x7b,
    i64_add = 0x7c,
    i64_sub = 0x7d,
    i64_mul = 0x7e,
    i64_div_s = 0x7f,
    i64_div_u = 0x80,
    i64_rem_s = 0x81,
    i64_rem_u = 0x82,
    i64_and = 0x83,
    i64_or = 0x84,
    i64_xor = 0x85,
    i64_shl = 0x86,
    i64_shr_s = 0x87,
    i64_shr_u = 0x88,
    i64_rotl = 0x89,
    i64_rotr = 0x8a,
    f32_abs = 0x8b,
    f32_neg = 0x8c,
    f32_ceil = 0x8d,
    f32_floor = 0x8e,
    f32_trunc = 0x8f,
    f32_nearest = 0x90,
    f32_sqrt = 0x91,
    f32_add = 0x92,
    f32_sub = 0x93,
    f32_mul = 0x94,
    f32_div = 0x95,
    f32_min = 0x96,
    f32_max = 0x97,
    f32_copysign = 0x98,
    f64_abs = 0x99,
    f64_neg = 0x9a,
    f64_ceil = 0x9b,
    f64_floor = 0x9c,
    f64_trunc = 0x9d,
    f64_nearest = 0x9e,
    f64_sqrt = 0x9f,
    f64_add = 0xa0,
    f64_sub = 0xa1,
    f64_mul = 0xa2,
    f64_div = 0xa3,
    f64_min = 0xa4,
    f64_max = 0xa5,
    f64_copysign = 0xa6,
    i32_wrap_i64 = 0xa7,
    i32_trunc_f32_s = 0xa8,
    i32_trunc_f32_u = 0xa9,
    i32_trunc_f64_s = 0xaa,
    i32_trunc_f64_u = 0xab,
    i64_extend_i32_s = 0xac,
    i64_extend_i32_u = 0xad,
    i64_trunc_f32_s = 0xae,
    i64_trunc_f32_u = 0xaf,
    i64_trunc_f64_s = 0xb0,
    i64_trunc_f64_u = 0xb1,
    f32_convert_i32_s = 0xb2,
    f32_convert_i32_u = 0xb3,
    f32_convert_i64_s = 0xb4,
    f32_convert_i64_u = 0xb5,
    f32_demote_f64 = 0xb6,
    f64_convert_i32_s = 0xb7,
    f64_convert_i32_u = 0xb8,
    f64_convert_i64_s = 0xb9,
    f64_convert_i64_u = 0xba,
    f64_promote_f32 = 0xbb,
    i32_reinterpret_f32 = 0xbc,
    i64_reinterpret_f64 = 0xbd,
    f32_reinterpret_i32 = 0xbe,
    f64_reinterpret_i64 = 0xbf


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

proc parseResultType: Result =
  if b in {0x7f, 0x7e, 0x7d, 0x7c}:
    parseValueType()
  else:
    assertP b == 0x40, "invlid result byte"
    return EmpryResult

proc parseBlockType: Block = parseResultType()

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

proc parseMemarg: Memarg = (parseLeb128U32(), parseLeb128U32())

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

