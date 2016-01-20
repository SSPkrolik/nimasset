import streams
import pegs
import times
import strutils

type
    ErrBadOgex* = ref object of Exception
        ## Bad-formed COLLADA error

    OgexLoader* = ref object
        ## Loads COLLADA (*.dae) format for 3D assets

    OgexGeometryNode* = ref object

    OgexScene* = ref object
        ## Scene imported from OGEX file format
        geometry: seq[OgexGeometryNode]

proc newOgexScene*(): OgexScene =
    ## Empty Ogex Scene constructore
    result.new
    result.geometry = @[]

proc load*(l: OgexLoader, s: Stream): OgexScene =
    ## Load OGEX-encoded data from stream

proc `$`(scene: OgexScene): string =
    ## Ogex string stringificator
    result = "scene.ogex {\n"
    result &= "}"


when isMainModule and not defined(js):
    let
        f = open("cube.ogex")
        fs = newFileStream(f)
        loader = OgexLoader.new
        scene = loader.load(fs)

    echo scene
