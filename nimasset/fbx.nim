import streams
import strutils

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

# <<< Property API <<< #

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
    case pt.char
    of 'C': return s.readChar()
    of 'Y': return s.readInt16()
    of 'L': return s.readInt64()
    of 'I': return s.readInt32()
    of 'S': return readLongString(s)
    of 'F': return s.readFloat32()
    of 'D': return s.readFloat64()
    #[
    of 'R':
        let bufSize: int = s.readUint32().int
        result.new()
        result.kind = ptRawBinary
        result.valueBinary = newSeq[char](bufSize)
        assert s.readData(addr(result.valueBinary[0]), bufSize) == bufSize
    of 'b':
        let
            arrayLength: int = s.readUint32().int
            arrayEncoding: int = s.readUint32().int
            arraySize: int = s.readUint32().int
        
    of 'd':
    of 'i':
    of 'l':
    of 'f':
    ]#
    else:
        assert(false, "Wrong property data type read from FBX file")

proc readNodeBinary(scene: Scene, s: Stream): Node =
    # Parse node encoded in binary FBX
    let endOffset = readNodeOffset(scene, s)
    if endOffset == 0:
        return nil
    let propCount = readNodeOffset(scene, s)
    let propLength = readNodeOffset(scene, s)

    # Read node name
    result = newNode()
    result.name = readShortString(s)

    # Read properties
    for propIdx in 0 .. propCount:
        let property = readPropertyBinary(scene, s)
        result.properties.add(property)

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
        let child = readNodeBinary(scene, s)
        if child.isNil():
            return (LoadResult.Success, scene)
        root.children.add(child)
    
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
