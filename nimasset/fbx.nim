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

    FBXVec2* = object
        ## 2-dimensional FBX vector
        x*: float64
        y*: float64

    FBXVec3* = object
        ## 3-dimensional FBX vector
        x*: float64
        y*: float64
        z*: float64

    FBXVec4* = object
        ## 4-dimensional FBX vector
        x*: float64
        y*: float64
        z*: float64
        w*: float64

    FBXMaxtrix* = array[0..15, float64]
        ## 4*4 FBX Matrix

    FBXQuat* = object
        ## FBX Quaternion type
        x*: float64
        y*: float64
        z*: float64
        w*: float64

    FBXColor* = object
        ## FBX Color type    
        r*: float32
        g*: float32
        b*: float32


    FBXLoader* = ref object
        ## Loads Autodesk FBX (*.fbx) format for 3D assets

    FBXElementPropertyKind* = uint8
        ## Data type of FBX Element Property

    FBXElementProperty* = object
        ## FBX Element Property

    FBXElement* = ref object
        ## Element of FBX Scene

    FBXObjectKind* {.pure.} = enum
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

    FBXObject* = ref object of RootObj
        ## FBX Object Base
        m_kind:   FBXObjectKind
        m_isNode: bool
        m_scene:  FBXScene

    FBXRoot* = ref object of FBXObject
        ## FBX Scene Root Object

    FBXScene* = ref object
        ## Scene imported from OGEX file format
        m_root_element: FBXElement
        m_root: FBXRoot

const
    fbxepkLong*:         FBXElementPropertyKind = 'L'.uint8
    fbxepkInteger*:      FBXElementPropertyKind = 'I'.uint8
    fbxepkString*:       FBXElementPropertyKind = 'S'.uint8
    fbxepkFloat*:        FBXElementPropertyKind = 'F'.uint8
    fbxepkDouble*:       FBXElementPropertyKind = 'D'.uint8
    fbxepkArrayDouble*:  FBXElementPropertyKind = 'd'.uint8
    fbxepkArrayInteger*: FBXElementPropertyKind = 'i'.uint8
    fbxepkArrayLong*:    FBXElementPropertyKind = 'l'.uint8
    fbxepkArrayFloat*:   FBXElementPropertyKind = 'f'.uint8

proc newFBXObject*(scene: FBXScene, element: FBXElement): FBXObject =
    ## Constructs new FBX Object linked to scene and element
    new(result)
    result.m_scene = scene

method kind*(obj: FBXObject): FBXObjectKind {.base.} = 
    ## Get FBXObject type
    raise newException(Exception, "Method not implemented")


proc rootElement*(scene: FBXScene): FBXElement = scene.m_root_element
    ## Get FBX Scene root element

proc root*(scene: FBXScene): FBXRoot = scene.m_root
    ## Get FBX Scene root object

proc newFBXScene*(): FBXScene =
    ## Empty FBX Scene constructor
    result.new()
    result.m_root_element = new(FBXElement)

proc newFBXScene*(path: string): FBXScene =
    ## Construct new FBX Scene from file
    result = newFBXScene()


proc load*(loader: FBXLoader, s: Stream, kind: FBXKind = FBXKind.Ascii): FBXScene =
    ## Load FBX-encoded data from stream
    if kind == FBXKind.Binary:
        raise new(ErrUnsupported)
    return newFBXScene()

proc `$`(scene: FBXScene): string =
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
