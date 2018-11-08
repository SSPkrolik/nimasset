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

    Scene* = ref object
        m_header: Header
        m_source: string

# >>> Scene Implementation >>> #

proc parseFbx(scene: Scene, s: Stream): Scene =
    ## Parses FBX file and returns scene
    assert s.readData(addr scene.m_header, sizeof(Header)) == sizeof(Header)


    return scene


proc source*(scene: Scene): string = scene.m_source
    ## Get source URI from which FBX was loaded

proc version*(scene: Scene): uint32 = scene.m_header.version
    ## FBX document source format version

proc `$`(scene: Scene): string =
    ## FBX Scene stringificator
    result = "FBX Scene (source: " & scene.source() & ", version: " & $scene.version() & ") {\n"
    result &= "}"
    
# <<< Scene Implementation <<< #

# >>> Public API >>> #

proc loadFbx*(path: string, format: FileFormat = FileFormat.Binary): Scene =
    ## Load FBX Scene from file 
    let 
        fs = newFileStream(path, fmRead, 4096)
        scene = new(Scene)
    
    scene.m_source = path
    
    return scene.parseFbx(fs)

# <<< Public API <<< #

when isMainModule and not defined(js):
    const fbxFile: string = "binary.fbx"
    
    let scene = try: loadFbx(fbxFile)
                except IOError: nil
    
    if scene.isNil():
        echo "[ERROR] Reading file: " & fbxFile
    
    echo scene
