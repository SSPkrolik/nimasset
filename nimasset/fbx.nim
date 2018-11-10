import streams
import strutils

type
    Header* {.packed.} = object
        magic:    array[0 .. 20, uint8]
        reserved: array[0 .. 1, uint8]
        version:  uint32

    FileFormat* {.pure.} = enum
        Ascii
        Binary

    Property* = ref object

    Node* = ref object
        ## FBX Scene tree node
        name*:    string
        children*:   seq[Node]
        properties*: seq[Property]

    LoadResult* {.pure.} = enum
        Init    = ("Scene is initialized but not loaded")
        Success = ("Successfully Loaded")
        BadData = ("Bad data format")

    Scene* = ref object
        ## FBX Scene
        root*:           Node

        m_header:        Header
        m_source:        string

# >> Property API >>> #

proc newProperty(): Property =
    result.new()

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

proc readPropertyBinary(scene: Scene, s: Stream): Property =
    # Parse node property
    result = newProperty()


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
    
    # Read FBX header
    assert s.readData(addr scene.m_header, sizeof(Header)) == sizeof(Header)

    # Create and set root node
    let root = newNode()
    root.name = "<root>"

    # Read nodes    
    while not s.atEnd():
        let child = readNodeBinary(scene, s)
        if child.isNil():
            return (LoadResult.Success, scene)
        root.children.add(child)
    
    scene.root = root

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
