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

