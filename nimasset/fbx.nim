## FBX Importer
import streams
import strutils

import zip / zlib

type PropertyType* = uint8
    ## Data type of FBX Element Property

const
    ptChar*:         PropertyType = 'C'.uint8  ## char property
    ptShort*:        PropertyType = 'Y'.uint8  ## int16 property
    ptLong*:         PropertyType = 'L'.uint8  ## int64 integer property
    ptInteger*:      PropertyType = 'I'.uint8  ## int32 property
    ptString*:       PropertyType = 'S'.uint8  ## string property
    ptFloat*:        PropertyType = 'F'.uint8  ## float32 property
    ptDouble*:       PropertyType = 'D'.uint8  ## float64 property
    ptRawBinary*:    PropertyType = 'R'.uint8  ## Binary (untyped)? data
    ptArrayBool*:    PropertyType = 'b'.uint8  ## bool array property
    ptArrayDouble*:  PropertyType = 'd'.uint8  ## float64 array property
    ptArrayInteger*: PropertyType = 'i'.uint8  ## int32 array property
    ptArrayLong*:    PropertyType = 'l'.uint8  ## int64 array property
    ptArrayFloat*:   PropertyType = 'f'.uint8  ## float32 array property

type
    Header {.packed.} = object
        ## FBX Binary File Format Header
        magic:    array[0 .. 20, uint8]
        reserved: array[0 .. 1, uint8]
        version:  uint32

    FileFormat* {.pure.} = enum
        ## FBX File Format
        Ascii
        Binary

    Encoding* {.pure.} = enum
        Uncompressed = (0.uint32, "Not Compressed")
        Compressed   = (1.uint32, "ZIP (deflate) Compressed")

    Property* = ref object
        ## FBX Node Property
        case kind*: PropertyType
        of ptChar:         valueChar*:         char
        of ptShort:        valueInt16*:        int16
        of ptLong:         valueInt64*:        int64
        of ptInteger:      valueInt32*:        int32
        of ptString:       valueString*:       string
        of ptFloat:        valueFloat32*:      float32
        of ptDouble:       valueFloat64*:      float64
        of ptRawBinary:    valueBinary*:       seq[char]
        of ptArrayBool:    valueArrayBool*:    seq[bool]
        of ptArrayDouble:  valueArrayFloat64*: seq[float64]
        of ptArrayInteger: valueArrayInt32*:   seq[int32]
        of ptArrayLong:    valueArrayInt64*:   seq[int64]
        of ptArrayFloat:   valueArrayFloat*:   seq[float32]
        else: discard

        arrayLength: int

    Node* = ref object
        ## FBX Scene tree node
        name*:       string
        children*:   seq[Node]
        properties*: seq[Property]

    LoadResult* {.pure.} = enum
        Unknown = ("Scene is initialized but not loaded")
        Success = ("Successfully Loaded")
        BadData = ("Bad data format")

    Scene* = ref object
        ## FBX Scene
        root*:    Node

        m_header: Header
        m_source: string


# >> Property API >>> #

converter scalarToProperty[T: char | int16 | int32 | int64 | float32 | float64 | string](value: T): Property =
    result.new()
    result.arrayLength = 1
    when T is char:
        result.kind = ptChar
        result.valueChar = value
    elif T is int16:
        result.kind = ptShort
        result.valueInt16 = value
    elif T is int32:
        result.kind = ptInteger
        result.valueInt32 = value
    elif T is int64:
        result.kind = ptLong
        result.valueInt64 = value
    elif T is float32:
        result.kind = ptFloat
        result.valueFloat32 = value
    elif T is float64:
        result.kind = ptDouble
        result.valueFloat64 = value
    elif T is string:
        result.kind = ptString
        result.valueString = value

proc propertyArrayTypeSize(pt: PropertyType): int =
    # Returns size of single element for array property size
    assert pt in [ptArrayBool, ptArrayDouble, ptArrayInteger, ptArrayFloat, ptArrayLong]
    return case pt
    of ptArrayBool: 1
    of ptArrayDouble: 8
    of ptArrayInteger: 4
    of ptArrayFloat: 4
    of ptArrayLong: 8
    else: 0

# <<< Property API <<< #

proc newProperty(kind: PropertyType): Property =
    result.new()
    result.kind = kind

proc `$`(property: Property): string =
    return "Property of type " & $property.kind.char

# >>> Node API >>> #

proc newNode(): Node =
    result.new()
    result.name = "<untitled>"
    result.children = @[]
    result.properties = @[]

# <<< Node API <<< #

# >>> Scene Implementation >>> #

proc readNodeOffset(scene: Scene, s: Stream): uint64 =
    # Read node byte offset depending on FBX version
    if scene.m_header.version >= 7500'u32:
        return s.readUint64()
    
    return s.readUint32().uint64

proc nodeEndOffset(scene: Scene): int =
    # Get node nested list end offset depending on FBX version
    if scene.m_header.version >= 7500'u32:
        return 25
    
    return 13

proc readShortString(s: Stream): string =
    # Read short string
    let length = s.readUint8()
    return s.readStr(length.int)

proc readLongString(s: Stream): string =
    # Read long string
    let length = s.readUint32()
    return s.readStr(length.int)

proc readPropertyBinary(scene: Scene, s: Stream): Property =
    # Parse node property
    let pt: PropertyType = s.readUint8()
    
    when not defined(release): echo "Property type: " & pt.char

    # Parse scalar node properties
    case pt.char
    of 'C': return s.readChar()
    of 'Y': return s.readInt16()
    of 'L': return s.readInt64()
    of 'I': return s.readInt32()
    of 'S': return readLongString(s)
    of 'F': return s.readFloat32()
    of 'D': return s.readFloat64()
    else:
        discard
    
    # Parse raw node property
    if char(pt) == 'R': 
        let bufSize: int = s.readUint32().int
        let newProperty = newProperty(ptRawBinary)
        when not defined(release): echo "Buffer size: " & $bufSize
        newProperty.valueBinary = newSeq[char](bufSize)
        assert s.readData(addr(newProperty.valueBinary[0]), bufSize) == bufSize
        return newProperty

    # Parse array node property
    let
        arrayLength: int = s.readUint32().int
        arrayEncoding: uint32 = s.readUint32()
        compressedLength: int = s.readUint32().int

    if Encoding(arrayEncoding) == Encoding.Compressed:
        # Parse compressed array node property
        var compressed: seq[char] = @[]
        compressed.setLen(compressedLength)
        assert s.readData(addr compressed[0], compressedLength) == compressedLength
        let uncompressed = zlib.uncompress(cast[cstring](addr compressed[0]), compressedLength)
        let uncStream = newStringStream(uncompressed)

        case pt.char
        of 'd':
            let newProperty = newProperty(ptArrayDouble)
            newProperty.valueArrayFloat64 = @[]
            while not uncStream.atEnd():
                newProperty.valueArrayFloat64.add(uncStream.readFloat64())
            return newProperty
        of 'b':
            let newProperty = newProperty(ptArrayBool)
            newProperty.valueArrayBool = @[]
            for c in uncompressed:
                newProperty.valueArrayBool.add(if c.uint8 == 1: true else: false)
            return newProperty
        of 'i':
            discard # TODO
        of 'l':
            discard # TODO
        of 'f':
            discard # TODO
        else:
            discard # TODO
    else:
        # Parse uncompressed array node property
        var uncompressed: string = ""
        uncompressed.setLen(arrayLength * propertyArrayTypeSize(pt))
        assert s.readData(addr uncompressed[0], arrayLength * propertyArrayTypeSize(pt)) == arrayLength * propertyArrayTypeSize(pt)
        let uncStream = newStringStream(uncompressed)

        case pt.char
        of 'd':
            let newProperty = newProperty(ptArrayDouble)
            newProperty.valueArrayFloat64 = @[]
            for _ in 0 ..< arrayLength:
                newProperty.valueArrayFloat64.add(uncStream.readFloat64())
            return newProperty            
        of 'b':
            let newProperty = newProperty(ptArrayBool)
            newProperty.valueArrayBool = @[]
            for c in uncompressed:
                newProperty.valueArrayBool.add(if c.uint8 == 1: true else: false)
            return newProperty
        of 'i':
            let newProperty = newProperty(ptArrayInteger)
            newProperty.valueArrayInt32 = @[]
            for _ in 0 ..< arrayLength:
                newProperty.valueArrayInt32.add(uncStream.readInt32())
            return newProperty
        of 'l':
            discard # TODO
        of 'f':
            discard # TODO
        else:
            discard # TODO

    # Unknown node property type was encountered
    assert(false, "Wrong property data type read from FBX file: " & $pt)

proc readNodeBinary(scene: Scene, s: Stream, parent: Node) =
    # Parse node encoded in binary FBX
    when not defined(release):
        var parserRecursiveLevel {.global.}: int = 1
    
    let endOffset = readNodeOffset(scene, s)
    if endOffset == 0:
        return
    let propCount = readNodeOffset(scene, s)
    let propLength = readNodeOffset(scene, s)

    # Read node name
    let parsedNode = newNode()
    parsedNode.name = readShortString(s)

    # Read properties
    for propIdx in 0 ..< propCount.int:
        let property = readPropertyBinary(scene, s)
        when not defined(release): echo "Property: " & $property
        parsedNode.properties.add(property)

    when not defined(release): echo "Parsing node: " & parsedNode.name & ", properties(" & $propCount & "), len(" & $propLength & "), endOffset(" & $s.getPosition() & " of " & $endOffset & ")"
    # when not defined(release): echo "End parsing properties offset: " & $s.getPosition() & " of " & $endOffset

    # Add node to tree
    parent.children.add(parsedNode)

    # Return if node does not include nested ones
    if s.getPosition() == endOffset.int:
        return

    # Read nested nodes
    while s.getPosition() < endOffset.int - scene.nodeEndOffset():
        readNodeBinary(scene, s, parsedNode)

    # Read end marker of nested nodes
    if scene.m_header.version >= 7500'u32:
        discard s.readStr(scene.nodeEndOffset())
    else:
        discard s.readStr(scene.nodeEndOffset())

proc parseFbxBinary(scene: Scene, s: Stream): tuple[result: LoadResult, scene: Scene] =
    # Parse binary FBX data, build up an FBX scene and return it
    
    # Read FBX header and check if data is not broken
    let headerIsGood: bool = s.readData(addr scene.m_header, sizeof(Header)) == sizeof(Header)
    if not headerIsGood:
        return (LoadResult.BadData, nil)

    # Create and set root node (which is a fake node for whole FBX document)
    let root = newNode()
    root.name = "<root>"

    # Read all FBX nodes
    while not s.atEnd():
        readNodeBinary(scene, s, root)

        # when not defined(release): echo "Parsed node: " & child.name

        # if child.isNil():
        #    return (LoadResult.Success, scene)
        # root.children.add(child)
    
    # Set scene root
    scene.root = root

    # If no error happened by this time, the scene was successfully loaded
    return (LoadResult.Success, scene)


proc source*(scene: Scene): string = scene.m_source
    ## Get source URI from which FBX was loaded

proc version*(scene: Scene): uint32 = scene.m_header.version
    ## FBX document source format version

proc `$`*(node: Node): string =
    ## Node stringificator
    result  = "{" & node.name & "}\n"
    result &= " - "

proc `$`*(scene: Scene): string =
    ## FBX Scene stringificator
    result = "FBX Scene (source: " & scene.source() & ", version: " & $scene.version() & ") {\n"
    result &= $scene.root & "\n"
    result &= "}"

proc parseFbxText(scene: Scene, s: Stream): tuple[result: LoadResult, scene: Scene] =
    # Parse text FBX data, build up an FBX scene and return it
    assert false, "Fbx Ascii decoding is not supported right now"
    
# <<< Scene Implementation <<< #

# >>> Public API >>> #

proc loadFbx*(path: string, format: FileFormat = FileFormat.Binary): tuple[result: LoadResult, scene: Scene] =
    ## Load FBX Scene from file 
    let 
        fs = newFileStream(path, fmRead, 4096)
        scene = new(Scene)
    
    when not defined(release): echo "Loading: " & path

    scene.m_source = path
    
    return if format == FileFormat.Binary: scene.parseFbxBinary(fs)
           else: scene.parseFbxText(fs)

# <<< Public API <<< #

when isMainModule and not defined(js):
    const fbxFile: string = "test001b.fbx"
    
    try:
        let (result, scene) = loadFbx(fbxFile)
        echo "Load result: ", $result
        echo scene
    except IOError:
        echo "[ERROR] Reading file: " & fbxFile
