import math
import options
import pegs
import streams
import strutils
import times
import zip / zlib

type
    ErrBadFBX* = ref object of Exception
        ## Bad-formed Autodesk FBX error

    FBXKind* {.pure.} = enum
        Binary
        Ascii

    Vec2* = object
        ## 2-dimensional FBX vector
        x*: float64
        y*: float64

    Vec3* = object
        ## 3-dimensional FBX vector
        x*: float64
        y*: float64
        z*: float64

    Vec4* = object
        ## 4-dimensional FBX vector
        x*: float64
        y*: float64
        z*: float64
        w*: float64

    DataView* = object
        pBegin*: ptr uint8
        pEnd*:   ptr uint8
        binary*: bool

    Matrix* = array[0..15, float64]
        ## 4*4 FBX Matrix

    Quat* = object
        ## FBX Quaternion type
        x*: float64
        y*: float64
        z*: float64
        w*: float64

    Color* = object
        ## FBX Color type    
        r*: float32
        g*: float32
        b*: float32

    RotationOrder* {.pure.} = enum
        EulerXYZ = 0,
        EulerXZY,
        EulerYZX,
        EulerYXZ,
        EulerZXY,
        EulerZYX,
        SphericXYZ  # Currently unsupported. Treated as EULER_XYZ.

    FBXLoader* = ref object
        ## Loads Autodesk FBX (*.fbx) format for 3D assets

    PropertyKind* = uint8
        ## Data type of FBX Element Property

    Property* = ref object
        ## FBX Element Property
        m_kind:  PropertyKind
        m_count: int
        m_value: DataView
        m_next:  Property

    Element* = ref object
        ## Element of FBX Scene
        m_id:            DataView
        m_child:         Element
        m_sibling:       Element
        m_firstProperty: Property

    ObjectKind* {.pure.} = enum
        ## Type of FBX Object
        Root               = (0,  "ROOT")
        Geometry           = (1,  "GEOMETRY")
        Material           = (2,  "MATERIAL")
        Mesh               = (3,  "MESH")
        Texture            = (4,  "TEXTURE")
        LimbNode           = (5,  "LIMB_NODE")
        NullNode           = (6,  "NULL_NODE")
        NodeAttribute      = (7,  "NODE_ATTRIBUTE")
        Cluster            = (8,  "CLUSTER")
        Skin               = (9,  "SKIN")
        AnimationStack     = (10, "ANIMATION_STACK")
        AnimationLayer     = (11, "ANIMATION_LAYER")
        AnimationCurve     = (12, "ANIMATION_CURVE")
        AnimationCurveNode = (13, "ANIMATION_CURVE_NODE")

    Object* = ref object of RootObj
        ## FBX Object Base
        m_id:            uint64
        m_name:          array[0 .. 127, char]
        m_element:       Element
        m_nodeAttribute: Object
        m_isNode:        bool
        m_scene:         Scene

    Root* = ref object of Object
        ## FBX Scene Root Object

    Scene* = ref object
        ## Scene imported from OGEX file format
        m_root_element: Element
        m_root: Root

    FBXHeader {.packed.} = object
        ## FBX File Header record
        magic:    array[0 .. 20, uint8]
        reserved: array[0 .. 1, uint8]
        version:  uint32

    Cursor = object
        ## Stream reading cursor
        pCurrent*: ptr uint8
        pBegin*:   ptr uint8
        pEnd*:     ptr uint8

const
    pkLong*:         PropertyKind = 'L'.uint8
    pkInteger*:      PropertyKind = 'I'.uint8
    pkString*:       PropertyKind = 'S'.uint8
    pkFloat*:        PropertyKind = 'F'.uint8
    pkDouble*:       PropertyKind = 'D'.uint8
    pkArrayDouble*:  PropertyKind = 'd'.uint8
    pkArrayInteger*: PropertyKind = 'i'.uint8
    pkArrayLong*:    PropertyKind = 'l'.uint8
    pkArrayFloat*:   PropertyKind = 'f'.uint8


# >>> Decompression #

proc decompress(pIn: ptr uint8, inSize: int, pOut: ptr uint8, outSize: int): bool =
    ## Zip-stream decompression
    var strm: ZStream = ZStream()
    discard strm.inflateInit()

    strm.availIn  = inSize.Uint
    strm.nextIn   = cast[cstring](pIn)
    strm.availOut = outSize.Uint
    strm.nextOut  = cast[cstring](pOut)

    let status: int32 = strm.inflate(Z_SYNC_FLUSH)

    if status != Z_STREAM_END:
        return false

    return strm.inflateEnd() == Z_OK

# <<< Decompression #

# >>> Math procedures #

proc `*`(v: Vec3, f: float32): Vec3 = Vec3(x: v.x * f, y: v.y * f, z: v.z * f)
    ## Multiply vector over scalar

proc `+`(a: Vec3, b: Vec3): Vec3 = Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
    ## Add two vectors

proc setTranslation(t: var Vec3, mtx: var Matrix) =
    ## Set translation into transform matrix
    mtx[12] = t.x
    mtx[13] = t.y
    mtx[14] = t.z

proc `-`(v: Vec3): Vec3 = Vec3( x: -v.x, y: -v.y, z: -v.z )
    ## Opposite vector

proc `*`(lhs: Matrix, rhs: Matrix): Matrix =
    ## Matrix multiplication
    for j in 0 ..< 4:
        for i in 0 ..< 4:
            var tmp: float64 = 0.0
            for k in 0 ..< 4:
                tmp += lhs[i + k * 4] * rhs[k + j * 4]
            result[i + j * 4] = tmp

proc makeIdentity(): Matrix = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
    ## Create identity matrix

proc rotationX(angle: float64): Matrix =
    ## Rotation around X axis as transformation matrix
    result = makeIdentity()
    let c: float64 = math.cos(angle)
    let s: float64 = math.sin(angle)
    
    result[10] = c
    result[5]  = c
    result[9]  = -s
    result[6]  = s

proc rotationY(angle: float64): Matrix =
    ## Rotation around Y axis as transformation matrix
    result = makeIdentity()
    let c: float64 = math.cos(angle)
    let s: float64 = math.sin(angle)
    
    result[10] = c
    result[0]  = c
    result[8]  = s
    result[2]  = -s

proc rotationZ(angle: float64): Matrix =
    ## Rotation around Z axis as transformation matrix
    result = makeIdentity()
    let c: float64 = math.cos(angle)
    let s: float64 = math.sin(angle)
    
    result[5]  = c
    result[0]  = c
    result[4]  = -s
    result[1]  = s

proc getRotationMatrix(euler: Vec3, order: RotationOrder): Matrix =
    ## Get rotation transformation matrix
    const kToRad: float64 = 3.1415926535897932384626433832795028 / 180.0;
    let rx: Matrix = rotationX(euler.x * kToRad)
    let ry: Matrix = rotationY(euler.y * kToRad)
    let rz: Matrix = rotationZ(euler.z * kToRad)

    case order
    of RotationOrder.SphericXYZ:
        assert(false)
    of RotationOrder.EulerXYZ:
        return rz * ry * rx
    of RotationOrder.EulerXZY:
        return ry * rz * rx
    of RotationOrder.EulerYXZ:
        return rz * rx * ry
    of RotationOrder.EulerYZX:
        return rx * rz * ry
    of RotationOrder.EulerZXY:
        return ry * rx * rz
    of RotationOrder.EulerZYX:
        return rx * ry * rz

proc fbxTimeToSeconds(value: int64): float64 = value.float64 / 46186158000.float64

proc secondsToFbxTime(value: float64): int64 = (value * 46186158000.float64).int64

# <<< Math procedures #

# >>> String procedures #

proc copyString[size: static int](destination: array[0 .. (size - 1), char], source: ptr char): bool =
    ## copies fixed-size string from source to destination
    var src: ptr char = source
    var dest: ptr char = destination
    var length: int = size
    
    if (src.isNil()):
        return false
    
    while src[] and length > 1:
        dest[] = src[]
        dec(length)
        dest = cast[ptr char](cast[ByteAddress](dest) + 1)
        src = cast[ptr char](cast[ByteAddress](src) + 1)
    dest[] = 0
    return src[] == '\0'

# <<< String procedures #

# >>> DataView procedures #

proc toU64(view: DataView): uint64 =
    ## Convert dataview data to unsigned 64-bit integer
    if (view.binary):
        assert(cast[ByteAddress](view.pEnd) - cast[ByteAddress](view.pBegin) == sizeof(uint64))
        return cast[uint64](view.pBegin[])
    return parseBiggestUInt($cast[cstring](view.pBegin))

proc toI64(view: DataView): int64 =
    ## Convert dataview data to signed 64-bit integer
    if (view.binary):
        assert(cast[ByteAddress](view.pEnd) - cast[ByteAddress](view.pBegin) == sizeof(int64))
        return cast[int64](view.pBegin[])
    return parseBiggestInt($cast[cstring](view.pBegin))

proc toInt(view: DataView): int =
    ## Convert dataview data to signed integer
    if (view.binary):
        assert(cast[ByteAddress](view.pEnd) - cast[ByteAddress](view.pBegin) == sizeof(int64))
        return cast[int](view.pBegin[])
    return parseInt($cast[cstring](view.pBegin))

proc toU32(view: DataView): uint32 =
    ## Convert dataview data to unsigned 32-bit integer
    if (view.binary):
        assert(cast[ByteAddress](view.pEnd) - cast[ByteAddress](view.pBegin) == sizeof(int64))
        return cast[uint32](view.pBegin[])
    return parseUInt($cast[cstring](view.pBegin)).uint32


proc toFloat64(view: DataView): float64 =
    ## Convert dataview data to 64-bit float
    if (view.binary):
        assert(cast[ByteAddress](view.pEnd) - cast[ByteAddress](view.pBegin) == sizeof(int64))
        return cast[float64](view.pBegin[])
    return parseFloat($cast[cstring](view.pBegin)).float64

proc toFloat32(view: DataView): float32 =
    ## Convert dataview data to unsigned 32-bit float
    if (view.binary):
        assert(cast[ByteAddress](view.pEnd) - cast[ByteAddress](view.pBegin) == sizeof(int64))
        return cast[float32](view.pBegin[])
    return parseUInt($cast[cstring](view.pBegin)).float32

proc toString[N: static int](view: DataView, pOut: ptr array[0 .. N-1, char]) =
    ## Convert dataview data to string
    var cout: ptr char
    var cin: ptr uint8
    while cin != view.pEnd and cast[ByteAddress](cout) - cast[ByteAddress](pOut) < N - 1:
        cout[] = cin[].char
        cin = cast[ptr uint8](cast[ByteAddress](cin) + 1)
        cout = cast[ptr char](cast[ByteAddress](cout) + 1)
    cout[] = '\0'

proc `==`(view: DataView, rhs: ptr char): bool =
    ## Compare dataview with raw string data
    var c:  ptr char = rhs
    var c2: ptr char = cast[ptr char](view.pBegin)

    while(c[] != '\0' and c2 != cast[ptr char](view.pEnd)):
        if (c[] != c2[]):
            return false
        c  = cast[ptr char](cast[ByteAddress](c) + 1)
        c2 = cast[ptr char](cast[ByteAddress](c2) + 1)

# <<< Property procedures #

proc fromString[T](pStr: cstring, pEnd: cstring, val: ptr T): cstring =
    ##
    when T is int:
        val[] = parseInt($pStr)
    elif T is uint64:
        val[] = parseBiggestUInt($pStr).uint64
    elif T is int64:
        val[] = parseBiggestInt($pStr).int64
    elif T is float64:
        val[] = parseFloat($pStr).float64
    elif T is float32:
        val[] = parseFloat($pStr).float32
    elif T is Vec2:
        return fromString(pStr, pEnd, addr val[].x, 2)
    elif T is Vec3:
        return fromString(pStr, pEnd, addr val[].y, 3)
    elif T is Vec4:
        return fromString(pStr, pEnd, addr val[].z, 4)
    elif T is Matrix:
        return fromString(pStr, pEnd, val, 16)

    var iter: cstring = pStr
    while cast[ByteAddress](iter) < cast[ByteAddress](pEnd) and cast[ptr char](iter)[] != ',':
        iter = cast[cstring](cast[ByteAddress](iter) + 1)
    
    return iter

proc fromString(pStr: cstring, pEnd: cstring, val: ptr float64, count: int): cstring =
    ## Parse from string
    var iter: cstring = pStr
    var valIter: ptr float64 = val

    for i in 0 ..< count:
        valIter[] = parseFloat($iter)
        valIter = cast[ptr float64](cast[ByteAddress](val) + sizeof(float64))
        while cast[ByteAddress](iter) < cast[ByteAddress](pEnd) and cast[ptr char](iter)[] != ',':
            iter = cast[cstring](cast[ByteAddress](iter) + 1)
        if iter == pEnd:
            return iter
    
    return iter

proc getCount*(property: Property): int =
    ## Get number of property data items
    assert(property.m_kind in [pkArrayDouble, pkArrayInteger, pkArrayFloat, pkArrayLong])
    if property.m_value.binary:
        return (cast[ptr uint32](property.m_value.pBegin)[]).int
    
proc parseTextArrayRaw[T](property: Property, pOutRaw: ptr T, maxSize: int): bool =
    ## Parse text array
    var iter: ptr uint8 = property.m_value.pBegin
    var pOut: ptr T = pOutRaw

    while cast[ByteAddress](iter) < cast[ByteAddress](property.m_value.pEnd):
        iter = cast[ptr uint8](fromString[T](cast[cstring](iter), cast[cstring](property.m_value.pEnd), pOut))
        pOut = cast[ptr T](cast[ByteAddress](pOut) + 1)
        if cast[ByteAddress](pOut) - cast[ByteAddress](pOutRaw) == (maxSize / sizeof(T)).int:
            return true
    
    return cast[ByteAddress](pOut) - cast[ByteAddress](pOutRaw) == (maxSize / sizeof(T)).int
    
proc parseArrayRaw[T](property: Property, pOut: ptr T, maxSize: int): bool =
    ## Parse raw array
    if property.m_value.binary:
        let elemSize: int = case property.m_kind
                            of pkArrayLong:    8
                            of pkArrayDouble:  8
                            of pkArrayFloat:   4
                            of pkArrayInteger: 4
                            else: 1

        let pData: ptr uint8 = cast[ptr uint8](cast[ByteAddress](property.m_value.pBegin) + sizeof(uint32) * 3)
        if (cast[ByteAddress](pData) > cast[ByteAddress](property.m_value.pEnd)):
            return false
        
        let count: uint32 = property.getCount().uint32
        let enc: uint32 = cast[ptr uint32](cast[ByteAddress](property.m_value.pBegin) + 4)[]
        let len: uint32 = cast[ptr uint32](cast[ByteAddress](property.m_value.pBegin) + 8)[]

        if enc == 0:
            if (len.int > maxSize): return false
            if (cast[ByteAddress](pData) + len.ByteAddress > cast[ByteAddress](property.m_value.pEnd)): return false
            copyMem(pOut, pData, len)
            return true
        elif enc == 1:
            if (elemSize * count.int > maxSize): return false
            return decompress(pData, len.int, cast[ptr uint8](pOut), elem_size * count.int)

        return false
    
    return parseTextArrayRaw(property, pOut, maxSize)

proc getType*(property: Property): PropertyKind = property.m_kind
    ## Return property type

proc getNext*(property: Property): Property = property.m_next
    ## Get next element property in list

proc getValue*(property: Property): DataView = property.m_value
    ## Get property value

proc getValues*[T:float64|float32|uint64|int64|int](property: Property, values: ptr T, maxSize: int): bool = parseArrayRaw(property, values, maxSize)

# <<< Property procedures #

# >>> Element procedures #

proc getFirstChild*(element: Element): Element = element.m_child
proc getSibling*(element: Element): Element = element.m_sibling
proc getId*(element: Element): DataView = element.m_id
proc getFirstProperty*(element: Element): Property = element.m_firstProperty

proc getProperty*(element: Element, idx: int): Property =
    ## Get property at index 'idx' in a list of element properties
    var prop: Property = element.m_firstProperty
    for i in 0 ..< idx:
        if prop.isNil():
            return nil
        prop = prop.getNext()
    return prop

proc findChild*(element: Element, id: cstring): Element =
    ## find child by id
    var iter: Element = element.m_child
    while not iter.isNil():
        if cast[cstring](iter.m_id.pBegin) == id:
            return iter
        iter = iter.m_sibling

# <<< Element procedures #

# >>> Object procedures #

proc newObject*(scene: Scene, element: Element): Object =
    ## Constructs new FBX Object linked to scene and element
    result.new()
    result.m_scene = scene
    result.m_element = element
    result.m_isNode = false
    result.m_nodeAttribute = nil

    let e: Element = element
    if not e.m_firstProperty.isNil() and not e.m_firstProperty.m_next.isNil():
        e.m_firstProperty.m_next.m_value.toString(addr result.m_name)

method kind*(obj: Object): ObjectKind {.base.} = 
    ## Get FBXObject type
    raise newException(Exception, "Method not implemented")

proc resolveProperty(obj: Object, name: cstring): Element =
    let props: Element = findChild(obj.m_element, "Properties70")
    if (props.isNil()):
        return nil
    
    var prop: Element = props.m_child
    while not prop.isNil():
        if not prop.m_firstProperty.isNil():
            if cast[cstring](prop.m_firstProperty.m_value.pBegin) == name:
                return prop
        prop = prop.m_sibling
    
    return nil

proc resolveEnumProperty(obj: Object, name: cstring, defaultValue: int): int =
    let element: Element = resolveProperty(obj, name)
    if element.isNil():
        return defaultValue
    let x: Property = element.getProperty(4)
    if x.isNil():
        return defaultValue
    
    return x.m_value.toInt()

proc resolveVec3Property(obj: Object, name: cstring, defaultValue: Vec3): Vec3 =
    let element: Element = resolveProperty(obj, name)
    if element.isNil():
        return defaultValue
    let x: Property = element.getProperty(4)
    if x.isNil() or x.m_next.isNil() or x.m_next.m_next.isNil():
        return defaultValue
    
    return Vec3(x: x.m_value.toFloat64(), y: x.m_next.m_value.toFloat64(), z: x.m_next.m_next.m_value.toFloat64())

# <<< Object procedures #

# >>> Cursor procedures #

proc read[T](cursor: var Cursor): Option[T] =
    ## Read data at cursor
    if cast[ByteAddress](cursor.pCurrent) + sizeof(T) > cast[ByteAddress](cursor.pEnd):
        # `Reading past the end`
        return none(T)
    cursor.pCurrent = cast[ptr uint8](cast[ByteAddress](cursor.pCurrent) + sizeof(T))
    return some(cast[ptr T](cursor.pCurrent)[])

proc readShortString(cursor: var Cursor): Option[DataView] =
    ## Read short string
    var value: DataView
    let length: Option[uint8] = read[uint8](cursor)
    if length.isNone():
        return none(DataView)  # error
    
    if cast[ByteAddress](cursor.pCurrent) + ByteAddress(length.get()) > cast[ByteAddress](cursor.pEnd):
        return none(DataView)  # error

    value.pBegin = cursor.pCurrent
    cursor.pCurrent = cast[ptr uint8](cast[ByteAddress](cursor.pCurrent) + length.get().ByteAddress)
    value.pEnd = cursor.pCurrent

    return some(value)

proc readLongString(cursor: var Cursor): Option[DataView] =
    ## Read long string
    var value: DataView
    let length: Option[uint32] = read[uint32](cursor)
    if length.isNone():
        return none(DataView)  # error
    
    if cast[ByteAddress](cursor.pCurrent) + ByteAddress(length.get()) > cast[ByteAddress](cursor.pEnd):
        return none(DataView)  # error

    value.pBegin = cursor.pCurrent
    cursor.pCurrent = cast[ptr uint8](cast[ByteAddress](cursor.pCurrent) + length.get().ByteAddress)
    value.pEnd = cursor.pCurrent

    return some(value)

proc readProperty(cursor: var Cursor): Option[DataView] =
    if (cursor.pCurrent == cursor.pEnd):
        return none(DataView)  # error
    
    
# <<< Cursor procedures #

proc rootElement*(scene: Scene): Element = scene.m_root_element
    ## Get FBX Scene root element

proc root*(scene: Scene): Root = scene.m_root
    ## Get FBX Scene root object

proc newFBXScene*(): Scene =
    ## Empty FBX Scene constructor
    result.new()
    result.m_root_element = new(Element)

proc newScene*(path: string): Scene =
    ## Construct new FBX Scene from file
    result = newFBXScene()

proc load*(loader: FBXLoader, s: Stream, kind: FBXKind = FBXKind.Ascii): Scene =
    ## Load FBX-encoded data from stream
    return newFBXScene()

proc `$`(scene: Scene): string =
    ## Ogex string stringificator
    result = "FBX Scene {\n"
    result &= "}"

when isMainModule and not defined(js):
    let
        f = open("teapot.fbx")
        fs = newFileStream(f)
        loader = FBXLoader.new
        scene = loader.load(fs)

    echo scene
