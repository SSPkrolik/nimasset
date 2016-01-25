import streams
import parsexml
import times
import strutils

type
    ErrBadCollada* = ref object of Exception
        ## Bad-formed COLLADA error

    ColladaLoader* = ref object
        ## Loads COLLADA (*.dae) format for 3D assets

    ColladaMaterial* = object
        ## Material info deserialized from dae (COLLADA) file.
        ## Contains material parameters for shading.
        name*: string
        emission*: array[4, float32]
        ambient*: array[4, float32]
        diffuse*: array[4, float32]
        specular*: array[4, float32]
        shininess*: float32
        reflective*: array[4, float32]
        reflectivity*: float32
        transparent*: array[4, float32]
        normalmap*: array[4, float32]
        transparency*: float32
        diffuseTextureName*: string
        specularTextureName*: string
        reflectiveTextureName*: string
        transparentTextureName*: string
        normalmapTextureName*: string

    ColladaImage* = object
        ## Reference to Image file
        name*: string
        location*: string

    ColladaFaceAccessor* = object
        vertexOfset*: int
        normalOfset*: int
        texcoordOfset*: int

    ColladaGeometry* = ref object
        name*: string
        materialName*: string
        vertices*: seq[float32]
        texcoords*: seq[float32]
        normals*: seq[float32]
        triangles*: seq[int]
        faceAccessor*: ColladaFaceAccessor

    ColladaNode* = ref object
        name*: string
        matrix*: string
        geometry*: string
        material*: string
        children*: seq[ColladaNode]

    ChannelKind* {.pure.} = enum
        ## Kind of channel interpretation (at least like Maya names it)
        Matrix     = "matrix"
        Visibility = "visibility"

    ColladaChannel* = ref object
        ## Collada Animation Channel
        source*: string
        target*: string
        kind*:   ChannelKind

    SourceKind* {.pure.} = enum
        ## Kind of source data stored in COLLADA file
        IDREF
        Name
        Bool
        Float
        Int

    ColladaSource* = ref object
        ## Source data stored in COLLADA file
        id*:            string
        case kind*:     SourceKind
        of SourceKind.IDREF:
        dataIDREF*:     seq[string]
        of SourceKind.Name:
        dataName*:      seq[string]
        of SourceKind.Bool:
        dataBool*:      seq[bool]
        of SourceKind.Float:
        dataFloat*:     seq[float32]
        of SourceKind.Int:
        dataInt*:       seq[int32]
        paramType*:     string

    ColladaInput = ref object
        ## Collada Input Definition
        semantic*: string
        source*:   string

    ColladaSampler* = ref object
        ## Collada Animation Sampler
        id*:            string
        input*:         ColladaInput
        output*:        ColladaInput
        inTangent*:     ColladaInput
        outTangent*:    ColladaInput
        interpolation*: ColladaInput

    ColladaAnimation* = ref object
        ## Collada Animation Descriptor
        id*:       string
        children*: seq[ColladaAnimation]
        sources* : seq[ColladaSource]
        sampler* : ColladaSampler
        channel* : ColladaChannel

    ColladaScene* = ref object
        path*: string
        pathShared*: string
        rootNode*: ColladaNode
        childNodesGeometry*: seq[ColladaGeometry]
        childNodesMaterial*: seq[ColladaMaterial]
        childNodesImages*:   seq[ColladaImage]
        animations*:         seq[ColladaAnimation]

    InterpolationKind* {.pure.} = enum
        Linear   = "LINEAR"
        Bezier   = "BEZIER"
        Cardinal = "CARDINAL"
        Hermite  = "HERMITE"
        Bspline  = "BSPLINE"
        Step     = "STEP"

const
    ## Input semantics kinds. These are made constants, not enums because 'semantics'
    ## value set is open, and may contain more values than those predefined
    ## in COLLADA 1.4 Standard.
    isInput*         = "INPUT"
    isInterpolation* = "INTERPOLATION"
    isInTangent*     = "IN_TANGENT"
    isOutTangent*    = "OUT_TANGENT"
    isOutput*        = "OUTPUT"

const
    ## Source param type defines how source data must be interpreted
    ptName*     = "name"
    ptFloat*    = "float"
    ptFloat4x4* = "float4x4"

const
    ## Collada XML Tag names according to COLLADA 1.4 Standard.
    csNone  = ""
    csAsset = "asset"
    csLibraryImages = "library_images"
    csLibraryMaterial = "library_materials"
    csLibraryEffect = "library_effects"
    csLibraryGeometries = "library_geometries"
    csLibraryVisualScenes = "library_visual_scenes"
    csMaterial = "material"
    csID = "id"
    csName = "name"
    csEffect = "effect"
    csColor = "color"
    csFloat = "float"
    csTexture = "texture"
    csImage = "image"
    csInitFrom = "init_from"
    csEmission = "emission"
    csAmbient = "ambient"
    csDiffuse = "diffuse"
    csSpecular = "specular"
    csShininess = "shininess"
    csReflective = "reflective"
    csReflectivity = "reflectivity"
    csTransparent = "transparent"
    csTransparency = "transparency"
    csNormalmap = "normalmap"
    csGeometry = "geometry"
    csSource = "source"
    csFloatArray = "float_array"
    csNameArray = "Name_array"
    csAccessor = "accessor"
    csTriangles = "triangles"
    csSemantic = "semantic"
    csOffset = "offset"
    csInput = "input"
    csMesh = "mesh"
    csVertices = "vertices"
    csP = "p"
    csVisualScene = "visual_scene"
    csScene = "scene"
    csNode = "node"
    csMatrix = "matrix"
    csInstanceGeometry = "instance_geometry"
    csInstanceMaterial = "instance_material"
    csInstanceVisualScene = "instance_visual_scene"
    csVisibility = "visibility"
    csLibraryAnimations = "library_animations"
    csAnimation = "animation"
    csChannel = "channel"
    csSampler = "sampler"
    csExtra   = "extra"
    csParam   = "param"

proc isComplex*(anim: ColladaAnimation): bool =
    ## Checks if animation is a complex animation (has subanimations) or not
    return if anim.children.len > 0: false else: true

proc parseArray4(source: string): array[0 .. 3, float32] =
    var i = 0
    for it in split(source):
        result[i] = parseFloat(it)
        inc(i)

proc newColladaGeometry(): ColladaGeometry =
    result.new()
    result.vertices = newSeq[float32]()
    result.texcoords = newSeq[float32]()
    result.normals = newSeq[float32]()
    result.triangles = newSeq[int]()

proc newColladaSource(kind: SourceKind): ColladaSource =
    ## Collada Source constructor
    result.new
    result.kind = kind
    case kind
    of SourceKind.IDREF:
        result.dataIDREF = @[]
    of SourceKind.Name:
        result.dataName  = @[]
    of SourceKind.Bool:
        result.dataBool  = @[]
    of SourceKind.Float:
        result.dataFloat = @[]
    of SourceKind.Int:
        result.dataInt   = @[]

proc newColladaChannel(): ColladaChannel =
    ## Create empty animation channel object
    result.new
    result.source = ""
    result.target = ""

proc newColladaSampler(): ColladaSampler =
    ## Create empty animation sampler object
    result.new
    result.id = ""

proc newColladaAnimation(): ColladaAnimation =
    ## Create empty animation object
    result.new
    result.id = ""
    result.children = @[]
    result.sources  = @[]

proc sourceById*(a: ColladaAnimation, n: string): ColladaSource =
    ## Returns source bound to animation by its id
    result = nil
    for s in a.sources:
        if s.id == n:
            return s

proc newColladaNode(): ColladaNode =
    result.new()
    result.children = newSeq[ColladaNode]()

proc newColladaScene(): ColladaScene =
    result.new()
    result.path = ""
    result.rootNode = newColladaNode()
    result.childNodesGeometry = @[]
    result.childNodesMaterial = @[]
    result.childNodesImages   = @[]
    result.animations         = @[]

proc parseImages(x: var XmlParser, images: var seq[ColladaImage]) = # collect textures location
    while true:
        x.next()
        case x.kind
        of xmlElementOpen:
            case x.elementName:
            of csImage:
                x.next()
                # img id = x.attrValue()[0 .. ^1]
                x.next()
                var img: ColladaImage
                img.name = x.attrValue()[0 .. ^1]
                while true:
                    x.next()
                    case x.kind
                    of xmlElementStart:
                        case x.elementName:
                        of csInitFrom:
                            x.next()
                            img.location = x.charData()[0 .. ^1]
                        else: discard
                    of xmlElementEnd:
                        case x.elementName:
                        of csImage: break
                        of csLibraryImages: break
                        else: discard
                    of xmlEof: break
                    else: discard
                images.add(img)
            else: discard
        of xmlElementEnd:
            case x.elementName:
            of csLibraryImages: break
            else: discard
        of xmlEof: break
        else: discard

proc parseMaterialElement(x: var XmlParser, matVector: var array[0 .. 3, float32], matTextureName: var string) =
    while true:
        x.next()
        case x.kind:
        of xmlElementOpen:
            case x.elementName:
            of csTexture:
                x.next()
                matTextureName = x.attrValue()[0 .. ^1]
                break
            of csColor:
                while x.kind != xmlCharData:
                    x.next()
                matVector = parseArray4(x.charData)
                break
            else: discard
        of xmlElementClose:
            break
        of xmlEof: break
        else: discard

proc parseMaterialEffect(x: var XmlParser, materials: var seq[ColladaMaterial]) = # material settings
    while true:
        x.next()
        case x.kind
        of xmlElementOpen:
            case x.elementName:
            of csEffect:
                var mat: ColladaMaterial
                x.next()
                mat.name = x.attrValue()[0 .. ^1]
                while true:
                    x.next()
                    case x.kind
                    of xmlElementStart:
                        case x.elementName:
                        of csEmission:
                            while x.kind != xmlCharData:
                                x.next()
                            mat.emission = parseArray4(x.charData)
                        of csAmbient:
                            while x.kind != xmlCharData:
                                x.next()
                            mat.ambient = parseArray4(x.charData)
                        of csDiffuse:
                            x.parseMaterialElement(mat.diffuse, mat.diffuseTextureName)
                        of csSpecular:
                            x.parseMaterialElement(mat.specular, mat.specularTextureName)
                        of csShininess:
                            while x.kind != xmlCharData:
                                x.next()
                            mat.shininess = parseFloat(x.charData)
                        of csReflective:
                            x.parseMaterialElement(mat.reflective, mat.reflectiveTextureName)
                        of csReflectivity:
                            while x.kind != xmlCharData:
                                x.next()
                            mat.reflectivity = parseFloat(x.charData)
                        of csTransparent:
                            x.parseMaterialElement(mat.transparent, mat.transparentTextureName)
                        of csTransparency:
                            while x.kind != xmlCharData:
                                x.next()
                            mat.transparency = parseFloat(x.charData)
                        of csNormalmap:
                            x.parseMaterialElement(mat.normalmap, mat.normalmapTextureName)
                        else: discard
                    of xmlElementEnd:
                        case x.elementName:
                        of csEffect: break
                        else: discard
                    of xmlEof: break
                    else: discard
                materials.add(mat)
            else: discard

        of xmlElementEnd:
            case x.elementName:
            of csLibraryEffect: break
            else: discard
        of xmlEof: break
        else: discard

proc parseMesh(x: var XmlParser, geomObject: ColladaGeometry) =
  var vertexSemantics = newSeq[string]()

  while true:
    x.next()
    case x.kind
    of xmlElementOpen:
      case x.elementName:
      of csFloatArray:
        x.next()
        var arrayID = x.attrValue[0 .. ^1]
        while x.kind != xmlCharData:
          x.next()
        if arrayID.contains("POSITION") or arrayID.contains("Position") or arrayID.contains("position"):
          for it in split(x.charData()):
            geomObject.vertices.add(parseFloat(it))
        elif arrayID.contains("NORMAL") or arrayID.contains("Normal") or arrayID.contains("normal"):
          for it in split(x.charData()):
            geomObject.normals.add(parseFloat(it))
        elif arrayID.contains("UV") or arrayID.contains("Uv") or arrayID.contains("uv"):
          for it in split(x.charData()):
            geomObject.texcoords.add(parseFloat(it))
        else:
          echo("no vertex data in node")
      of csVertices:
        while true:
          x.next()
          case x.kind
          of xmlElementOpen:
            case x.elementName:
            of csInput:
              x.next()
              vertexSemantics.add(x.attrValue[0 .. ^1])
            else: discard
          of xmlElementEnd:
            case x.elementName:
            of csVertices: break
            else: discard
          of xmlEof: break
          else: discard
      of csTriangles:
        x.next()
        x.next()
        geomObject.materialName = x.attrValue[0 .. ^1]
        while true:
          x.next()
          case x.kind
          of xmlElementOpen:
            case x.elementName:
            of csInput:
              x.next()
              var semantic = x.attrValue[0 .. ^1]
              x.next()
              var offset = parseInt(x.attrValue)
              if semantic == "VERTEX":
                for it in vertexSemantics:
                  if it == "POSITION":
                    geomObject.faceAccessor.vertexOfset = offset
                  if it == "NORMAL":
                    geomObject.faceAccessor.normalOfset = offset
                  if it == "TEXCOORD":
                    geomObject.faceAccessor.texcoordOfset = offset
              elif semantic == "NORMAL":
                geomObject.faceAccessor.normalOfset = offset
              elif semantic == "TEXCOORD":
                geomObject.faceAccessor.texcoordOfset = offset
              else:
                echo("corrupt face data")
            else: discard
          of xmlElementStart:
            case x.elementName:
            of csP:
              x.next()
              for it in split(x.charData()[0 .. ^1]):
                geomObject.triangles.add(parseInt(it))
            else: discard
          of xmlElementEnd:
            case x.elementName:
            of csTriangles: break
            else: discard
          of xmlEof: break
          else: discard
      else: discard
    of xmlElementEnd:
      case x.elementName:
      of csMesh: break
      else: discard
    of xmlEof: break
    else: discard

proc parseGeometry(x: var XmlParser, geom: var seq[ColladaGeometry]) =
  while true:
    x.next()
    case x.kind
    of xmlElementOpen:
      case x.elementName:
      of csGeometry:
        let geomObject = newColladaGeometry()
        geom.add(geomObject)
        x.next()
        geomObject.name = x.attrValue[0 .. ^1]
        while true:
          x.next()
          case x.kind
          of xmlElementStart:
            case x.elementName:
            of csMesh:
              x.parseMesh(geomObject)
            else: discard
          of xmlElementEnd:
            case x.elementName:
            of csGeometry: break
            else: discard
          of xmlEof: break
          else: discard
      else: discard
    of xmlElementEnd:
      case x.elementName:
      of csLibraryGeometries: break
      else: discard
    of xmlEof: break
    else: discard

proc parseNode(x: var XmlParser): ColladaNode =
  result = newColladaNode()

  while true:
    x.next()
    case x.kind
    of xmlAttribute:
      case x.attrKey:
      of csName:
         result.name = x.attrValue()[0 .. ^1]
      else: discard
    of xmlElementOpen:
      case x.elementName:
      of csMatrix:
        while true:
          x.next()
          case x.kind
          of xmlElementClose: break
          of xmlEof: break
          else: discard
        x.next()
        result.matrix = x.charData()[0 .. ^1]
      of csInstanceMaterial:
        x.next()
        result.material = x.attrValue()[0 .. ^1]
      of csInstanceGeometry:
        x.next()
        result.geometry = x.attrValue()[0 .. ^1]
      of csNode:
        result.children.add(parseNode(x))
      else: discard
    of xmlElementEnd:
      case x.elementName:
      of csNode: break
      else: discard
    of xmlEof: break
    else: discard

proc parseChannel(x: var XmlParser): ColladaChannel =
    ## Parse <channel> tag
    result.new
    result.source = ""
    result.target = ""

    while true:
        case x.kind
        of xmlAttribute:
            case x.attrKey
            of "source":
                result.source = x.attrValue[1..^0]
            of "target":
                result.target = x.attrValue.split("/")[0]
                result.kind = case x.attrValue.split("/")[^1]
                              of "matrix": ChannelKind.Matrix
                              of "visibility": ChannelKind.Visibility
                              else: ChannelKind.Matrix
            else:
                discard
        of xmlElementEnd:
            break
        else:
            discard
        x.next()

proc parseInput(x: var XmlParser): ColladaInput =
    ## Parse <input> tag
    result.new
    result.semantic = ""
    result.source = ""

    while true:
        case x.kind
        of xmlAttribute:
            case x.attrKey
            of "semantic":
                result.semantic = x.attrValue
            of "source":
                result.source = x.attrValue[1..^0]
            else:
                discard
        of xmlElementClose:
            break
        else:
            discard
        x.next()

proc parseSampler(x: var XmlParser): ColladaSampler =
    ## Parse <spampler> tag
    result.new

    while true:
        case x.kind
        of xmlElementOpen:
            case x.elementName
            of csInput:
                let newInput = x.parseInput()
                case newInput.semantic
                of isInput:
                    result.input = newInput
                of isOutput:
                    result.output = newInput
                of isInTangent:
                    result.inTangent = newInput
                of isOutTangent:
                    result.outTangent = newInput
                of isInterpolation:
                    result.interpolation = newInput
                else:
                    discard
            else:
                discard
        of xmlAttribute:
            if x.attrKey == "id":
                result.id = x.attrValue
        of xmlElementEnd:
            if x.elementName == csSampler:
                break
        else:
            discard
        x.next()

proc parseSource(x: var XmlParser): ColladaSource =
    ## Parse <source> tag
    result.new

    var
        localContext = csSource
        counter = 0

    while true:
        x.next()
        case x.kind
        of xmlAttribute:
            if x.attrKey == "id":
                if localContext == csSource:
                    result.id = x.attrValue
                elif localContext == csFloatArray:
                    result.kind = SourceKind.Float
                    result.dataFloat = @[]
                elif localContext == csNameArray:
                    result.kind = SourceKind.Name
                    result.dataName = @[]
            elif x.attrKey == "count":
                counter = x.attrValue.parseInt()
            elif x.attrKey == "type":
                if localContext == csParam:
                    result.paramType = x.attrValue
        of xmlCharData:
            for line in x.charData.strip().split("\n"):
                for piece in line.split(" "):
                    if result.kind == SourceKind.Float:
                        result.dataFloat.add(piece.parseFloat())
                    else:
                        result.dataName.add(piece)
        of xmlElementOpen:
            if x.elementName == csFloatArray:
                localContext = csFloatArray
            elif x.elementName == csNameArray:
                localContext = csNameArray
            elif x.elementName == csParam:
                localContext = csParam
        of xmlElementEnd:
            if x.elementName == csSource:
                break
        else:
            discard

proc parseAnimation(x: var XmlParser): ColladaAnimation =
    ## Parse <animation> tag
    result = newColladaAnimation()

    while true:
        x.next()
        case x.kind
        of xmlAttribute:
            case x.attrKey
            of "id":
                result.id = x.attrValue
            else:
                discard
        of xmlElementStart:
            if x.elementName == csAnimation:
                result.children.add(x.parseAnimation())
        of xmlElementOpen:
            case x.elementName
            of csAnimation:
                discard
            of csChannel:
                result.channel = x.parseChannel()
            of csSource:
                result.sources.add(x.parseSource())
            of csSampler:
                result.sampler = x.parseSampler()
            else:
                discard
        of xmlElementClose:
            continue
        of xmlElementEnd:
            case x.elementName
            of csAnimation:
                return result
            else:
                discard
        else:
            discard

proc parseAnimations(x: var XmlParser, cs: var ColladaScene) =
    ## Parse <library_animations> tag
    while true:
        x.next()
        case x.kind
        #of xmlElementStart:
        #    echo "START: ", x.elementName
        #    case x.elementName
        #    of csAnimation:
        #        echo "ADDING ANIMATION"
        #        #cs.animations.add(x.parseAnimation())
        #    else:
        #        discard
        of xmlElementOpen:
            cs.animations.add(x.parseAnimation())
        of xmlElementEnd:
            case x.elementName
            of csLibraryAnimations:
                break
            else:
                discard
        else:
            discard

proc parseScene(x: var XmlParser, cs: var ColladaScene) =
    ## Parse entire scene stored in COLLADA file
    while true:
        x.next()
        case x.kind
        of xmlElementOpen:
            case x.elementName:
            of csVisualScene:
                x.next()
                # sceneNodeID = x.attrValue
                x.next()
                cs.rootNode.name = x.attrValue()[0 .. ^1]
            of csNode:
                cs.rootNode.children.add(parseNode(x))
            else:
                discard
        of xmlElementEnd:
            case x.elementName:
            of csLibraryVisualScenes:
                break
            else:
                discard
        of xmlEof:
            break
        else:
            discard

proc load*(loader: ColladaLoader, s: Stream): ColladaScene =
    ## Load Entire Scene from COLLADA file
    result = newColladaScene()

    var x: XmlParser
    x.open(s, "")
    x.next()

    while true:
        case x.kind
        of xmlElementStart:
            case x.elementName
            of csLibraryImages:
                x.parseImages(result.childNodesImages)
            of csLibraryEffect:
                x.parseMaterialEffect(result.childNodesMaterial)
            of csLibraryGeometries:
                x.parseGeometry(result.childNodesGeometry)
            of csLibraryVisualScenes:
                x.parseScene(result)
            of csLibraryAnimations:
                x.parseAnimations(result)
            else:
                x.next()
        of xmlEof:
            break
        else:
            x.next()

proc `$`*(c: ColladaChannel): string =
    ## Return text representation of the animation channel
    if not isNil(c):
        return "Channel (source: ...$#, target: .../$#, kind: $#)" % [c.source[^20..^0], c.target.split("/")[1], $c.kind]
    else:
        return "Channel NIL"

proc `$`*(c: ColladaInput): string =
    return "       * $# source: ...$#)" % [c.semantic, c.source[^20..^0]]

proc `$`*(s: ColladaSampler): string =
    ## Return text representation of the sampler
    result = "Sampler (id: $#):\n" % [s.id]
    if not isNil(s.input): result &= $s.input & "\n"
    else: result &= "       * nil\n"
    if not isNil(s.output): result &= $s.output & "\n"
    else: result &= "       * nil\n"
    if not isNil(s.inTangent): result &= $s.inTangent & "\n"
    else: result &= "       * nil\n"
    if not isNil(s.outTangent): result &= $s.outTangent & "\n"
    else: result &= "       * nil\n"
    if not isNil(s.interpolation): result &= $s.interpolation
    else: result &= "       * nil"


proc `$`*(c: ColladaSource): string =
    ## Return text representation of the animation source
    result = "Source (id: ...$#, kind: $#, paramType: $#, data: " % [($c.id)[^20..^0], $c.kind, $c.paramType]

    case c.kind
    of SourceKind.IDREF:
        result &= "$#...] ($#)" % [($c.dataIDREF)[0..40], $c.dataIDREF.len]
    of SourceKind.Name:
        result &= "$#...] ($#)" % [($c.dataName)[0..40], $c.dataName.len]
    of SourceKind.Bool:
        result &= "$#...] ($#)" % [($c.dataBool)[0..40], $c.dataBool.len]
    of SourceKind.Float:
        result &= "$#...] ($#)" % [($c.dataFloat)[0..40], $c.dataFloat.len]
    of SourceKind.Int:
        result &= "$#...] ($#)" % [($c.dataInt)[0..40], $c.dataInt.len]

proc `$`*(anim: ColladaAnimation): string =
    ## Text representation of animation info
    result = "   * Animation: $#\n" % [anim.id]
    if not isNil(anim.channel):
        result &= "     * $#\n" % [$anim.channel]
    if not isNil(anim.sampler):
        result &= "     * $#\n" % [$anim.sampler]
    for source in anim.sources:
        result &= "     * $#\n" % [$source]
    if anim.children.len > 0:
        result &= "   | Animation children:\n"
    for a in anim.children:
        result &= $a
    if anim.children.len > 0:
        result &= "   ---------------------"

proc `$`*(scene: ColladaScene): string =
    ## Perform text representaiton of the scene
    result =  "COLLADA Scene: '" & scene.path & "'\n"
    result &= " * Animations [$#]: \n" % [$scene.animations.len]
    for anim in scene.animations:
        result &= $anim

when isMainModule and not defined(js):
    let
        f = open("balloon_animation_test.dae")
        fs = newFileStream(f)
        loader = ColladaLoader.new
        scene = loader.load(fs)

    echo scene
