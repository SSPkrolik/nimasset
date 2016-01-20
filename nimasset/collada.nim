import streams
import parsexml
import times
import strutils

type
  ErrBadCollada = ref object of Exception

  ColladaLoader* = ref object ## Loads COLLADA (*.dae) format for 3D assets

type 
  ColladaMaterial* = object
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
    childs*: seq[ColladaNode]

  ColladaScene* = ref object
    path*: string 
    pathShared*: string
    rootNode*: ColladaNode
    childNodesGeometry*: seq[ColladaGeometry]
    childNodesMaterial*: seq[ColladaMaterial]
    childNodesImages*: seq[ColladaImage]

const
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

proc newColladaGeometry(): ColladaGeometry = 
  result.new()
  result.vertices = newSeq[float32]()
  result.texcoords = newSeq[float32]()
  result.normals = newSeq[float32]()
  result.triangles = newSeq[int]()

proc newColladaNode(): ColladaNode = 
  result.new()
  result.childs = newSeq[ColladaNode]()

proc newColladaScene(): ColladaScene = 
  result.new()
  result.rootNode = newColladaNode()
  result.childNodesGeometry = newSeq[ColladaGeometry]()
  result.childNodesMaterial = newSeq[ColladaMaterial]()
  result.childNodesImages = newSeq[ColladaImage]()

proc parseArray4(source: string): array[0 .. 3, float32] = 
  var i = 0
  for it in split(source):
    result[i] = parseFloat(it)
    inc(i)

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
      case x.elementName:
      of csTexture: break
      of csEffect: break
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
        result.childs.add(parseNode(x))
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
        cs.rootNode.childs.add(parseNode(x))
      else: discard
    of xmlElementEnd: 
      case x.elementName:
      of csLibraryVisualScenes: break
      else: discard
    of xmlEof: break
    else: discard

proc load*(s: Stream): ColladaScene =
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

  let scene = loader.load(fs)
