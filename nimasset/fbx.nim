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

    FBXLoader* = ref object
        ## Loads Autodesk FBX (*.fbx) format for 3D assets

    FBXGeometryNode* = ref object

    FBXScene* = ref object
        ## Scene imported from OGEX file format
        geometry: seq[FBXGeometryNode]

proc newFBXScene*(): FBXScene =
    ## Empty Ogex Scene constructore
    result.new
    result.geometry = @[]

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
