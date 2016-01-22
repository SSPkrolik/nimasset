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

    ColladaScene* = ref object
        rootNode*: ColladaNode
        childNodesGeometry*: seq[ColladaGeometry]
        childNodesMaterial*: seq[ColladaMaterial]
        childNodesImages*: seq[ColladaImage]

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

    ColladaChannel* = ref object
        ## Collada Animation Channel

    InterpolationKind* {.pure.} = enum
        Linear   = "LINEAR"
        Bezier   = "BEZIER"
        Cardinal = "CARDINAL"
        Hermite  = "HERMITE"
        Bspline  = "BSPLINE"
        Step     = "STEP"

    ColladaInput = ref object
        ## Collada Input Definition
        semantics*: string
        source*: ColladaSource

    ColladaSampler* = ref object
        ## Collada Animation Sampler
        inputs*: seq[ColladaInput]

    ColladaAnimation* = ref object
        children*: seq[ColladaAnimation]
        sources* : seq[ColladaSource]
        sampler* : ColladaSampler
        channel* : ColladaChannel

const
    ## Input semantics kinds. These are made constants, not enums because 'semantics'
    ## value set is open, and may contain more values than those predefined
    ## in COLLADA 1.4 Standard.
    isInput         = "INPUT"
    isInterpolation = "INTERPOLATION"
    isInTangent     = "IN_TANGENT"
    isOutTangent    = "OUT_TANGENT"
    isOutput        = "OUTPUT"

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
    csLibraryAnimation = "library_animations"
    csAnimation = "animation"
    csChannel = "channel"
    csSampler = "sampler"
    csExtra   = "extra"

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

proc newColladaAnimation(): ColladaAnimation =
    ## Create empty animation object
    result.new
    result.sampler.new
    result.channel.new
    result.children = @[]
    result.sources  = @[]

proc newColladaNode(): ColladaNode =
    result.new()
    result.children = newSeq[ColladaNode]()

proc newColladaScene(): ColladaScene =
    result.new()
    result.rootNode = newColladaNode()
    result.childNodesGeometry = newSeq[ColladaGeometry]()
    result.childNodesMaterial = newSeq[ColladaMaterial]()
    result.childNodesImages = newSeq[ColladaImage]()

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

proc parseAnimation(x: var XmlParser, cs: var ColladaScene) =
    ## Parse <animation> tag

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

proc parseScene(x: var XmlParser, cs: var ColladaScene) =
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
      else: discard
    of xmlElementEnd:
      case x.elementName:
      of csLibraryVisualScenes: break
      else: discard
    of xmlEof: break
    else: discard

proc load*(loader: ColladaLoader, s: Stream): ColladaScene =
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
      # of csLibraryMaterial:
      #   x.parseMaterial() # material id and name
      of csLibraryEffect:
        x.parseMaterialEffect(result.childNodesMaterial)
      of csLibraryGeometries:
        x.parseGeometry(result.childNodesGeometry)
      of csLibraryVisualScenes:
        x.parseScene(result)
      else:
        x.next()
    of xmlEof: break
    else: x.next()

when isMainModule and not defined(js):
  let
    f = open("cube.dae")
    fs = newFileStream(f)
    loader = ColladaLoader.new

  discard loader.load(fs)
