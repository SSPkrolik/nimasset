import math
import streams
import pegs
import times
import strutils

type
    ErrBadFBX* = ref object of Exception
        ## Bad-formed Autodesk FBX error

    ErrUnsupported* = ref object of Exception
        ## Something is unsupported here

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

    ElementPropertyKind* = uint8
        ## Data type of FBX Element Property

    Property* = ref object
        ## FBX Element Property
        m_kind:  ElementPropertyKind
        m_count: int
        m_value: DataView
        m_next:  Property

    Element* = ref object
        ## Element of FBX Scene

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
        m_kind:   ObjectKind
        m_isNode: bool
        m_scene:  Scene

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
    epkLong*:         ElementPropertyKind = 'L'.uint8
    epkInteger*:      ElementPropertyKind = 'I'.uint8
    epkString*:       ElementPropertyKind = 'S'.uint8
    epkFloat*:        ElementPropertyKind = 'F'.uint8
    epkDouble*:       ElementPropertyKind = 'D'.uint8
    epkArrayDouble*:  ElementPropertyKind = 'd'.uint8
    epkArrayInteger*: ElementPropertyKind = 'i'.uint8
    epkArrayLong*:    ElementPropertyKind = 'l'.uint8
    epkArrayFloat*:   ElementPropertyKind = 'f'.uint8


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

proc getRorationMatrix(euler: Vec3, order: RotationOrder): Matrix =
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

proc parseArrayRaw[T](property: Property, maxSize: int): seq[T] =
    ## Parse raw array
    result = @[]
    if property.m_value.binary:
        let elemSize: int = case property.m_kind
                            of epkArrayLong:    8
                            of epkArrayDouble:  8
                            of epkArrayFloat:   4
                            of epkArrayInteger: 4
                            else: 0

proc toU64*(view: DataView): uint64 =
    ##

proc toI64*(view: DataView): int64 =
    ##

proc toInt*(view: DataView): int =
    ##

proc toU32*(view: DataView): int =
    ##

proc toFloat64*(view: DataView): float64 =
    ##

proc toFloat32*(view: DataView): float32 =
    ##

method kind*(property: Property): ElementPropertyKind {.base.} = property.m_kind
    ## Returns Element Property Type

method next*(property: Property): Property {.base.} = property.m_next
    ## Returns element's next property

method value*(property: Property): DataView {.base.} = property.m_value
    ## Get value of element property

method count*(property: Property): int {.base.} =
    ## Get number of pieces in element's property
    assert property.m_kind in [epkArrayDouble, epkArrayInteger, epkArrayFloat, epkArrayLong]
    if property.m_value.binary:
        return int(cast[ptr uint32](property.m_value.pBegin)[])
    return property.m_count

proc newObject*(scene: Scene, element: Element): Object =
    ## Constructs new FBX Object linked to scene and element
    new(result)
    result.m_scene = scene

method kind*(obj: Object): ObjectKind {.base.} = 
    ## Get FBXObject type
    raise newException(Exception, "Method not implemented")

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
    if kind == FBXKind.Binary:
        raise new(ErrUnsupported)
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
