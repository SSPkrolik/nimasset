import streams
import parsexml
import times
import strutils

type
  ErrBadCollada = ref object of Exception

  ColladaLoader* = ref object ## Loads COLLADA (*.dae) format for 3D assets

type ColladaMaterial* = object
  name*: string
  emission*: string
  ambient*: string
  diffuse*: string
  specular*: string
  shininess*: string
  reflective*: string
  reflectivity*: string
  transparent*: string
  transparency*: string
  diffuseTextureName*: string
  specularTextureName*: string
  reflectiveTextureName*: string
  transparentsTextureName*: string

type ColladaImage* = object
  name*: string
  location*: string

type ColladaFaceAccessor* = object
  vertexOfset*: int
  normalOfset*: int
  texcoordOfset*: int

type ColladaGeometry* = ref object
  name*: string
  vertices*: seq[float32]
  texcoords*: seq[float32]
  normals*: seq[float32]
  triangles*: seq[int]
  faceAccessor*: ColladaFaceAccessor
  materialName*: string

proc newColladaGeometry(): ColladaGeometry = 
  result.new()
  result.vertices = newSeq[float32]()
  result.texcoords = newSeq[float32]()
  result.normals = newSeq[float32]()
  result.triangles = newSeq[int]()
  
type ColladaScene* = ref object
  name*: string
  childNodesNames*: seq[string]
  childNodesMatrices*: seq[string]
  childNodesAlpha*: seq[float32]
  childNodesGeometry*: seq[ColladaGeometry]
  childNodesMaterial*: seq[ColladaMaterial]
  childNodesImages*: seq[ColladaImage]

proc newColladaScene(): ColladaScene = 
  result.new()
  result.childNodesNames = newSeq[string]()
  result.childNodesMatrices = newSeq[string]()
  result.childNodesAlpha = newSeq[float32]()
  result.childNodesGeometry = newSeq[ColladaGeometry]()
  result.childNodesMaterial = newSeq[ColladaMaterial]()
  result.childNodesImages = newSeq[ColladaImage]()

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

proc parseImages(x: var XmlParser, images: var seq[ColladaImage]) = # collect textures location
  while true:
    x.next()
    case x.kind
    of xmlElementOpen:
      case x.elementName:
      of csImage: 
        x.next()
        # img id = x.attrValue()
        x.next()

        var img: ColladaImage
        img.name = x.attrValue()

        while true:
          x.next()
          case x.kind
          of xmlElementStart:
            case x.elementName:
            of csInitFrom:
              x.next()

              img.location = x.charData()

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

proc parseMaterialElement(x: var XmlParser, matVector: var string, matTextureName: var string) = 
  while true:
    x.next()
    case x.kind:
    of xmlElementOpen:
      case x.elementName:
      of csTexture:
        x.next()
        matTextureName = x.attrValue
        break
      of csColor:
        while x.kind != xmlCharData:
          x.next()
        matVector = x.charData()
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
      # of csID: effectID.add(x.attrValue())
      of csEffect: 
        var mat: ColladaMaterial
        
        x.next()
        mat.name = x.attrValue()

        while true:
          x.next()
          case x.kind
          of xmlElementStart:
            case x.elementName:
            of csEmission: 
              while x.kind != xmlCharData:
                x.next()
              mat.emission = x.charData()
            of csAmbient:
              while x.kind != xmlCharData:
                x.next()
              mat.ambient = x.charData()
            of csDiffuse:
              x.parseMaterialElement(mat.diffuse, mat.diffuseTextureName)
            of csSpecular: 
              x.parseMaterialElement(mat.specular, mat.specularTextureName)
            of csShininess: 
              while x.kind != xmlCharData:
                x.next()
              mat.shininess = x.charData()
            of csReflective: 
              x.parseMaterialElement(mat.reflective, mat.reflectiveTextureName)
            of csReflectivity: 
              while x.kind != xmlCharData:
                x.next()
              mat.reflectivity = x.charData()
            of csTransparent: 
              x.parseMaterialElement(mat.transparent, mat.transparentsTextureName)
            of csTransparency:
              while x.kind != xmlCharData:
                x.next()
              mat.transparency = x.charData()
            else: discard
          of xmlElementEnd:
            case x.elementName:
            of csEffect: break
            # of csLibraryEffect: break
            else: discard
          of xmlEof: break
          else: discard

        materials.add(mat)

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
        var arrayID = x.attrValue
        x.next()
        # var arraySize = parseInt(x.attrValue)
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
              vertexSemantics.add(x.attrValue) # collect VERTEX "childs" to compute strides in faces for vertices and normals
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

        geomObject.materialName = x.attrValue

        while true:
          x.next()
          case x.kind
          of xmlElementOpen:
            case x.elementName:
            of csInput:
              x.next()
              var semantic = x.attrValue
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
              for it in split(x.charData()):
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

proc parseGeometry(x: var XmlParser, geom: var seq[ColladaGeometry]) = # need merge vertex attrib data
  while true:
    x.next()
    case x.kind
    of xmlElementOpen:
      case x.elementName:
      of csGeometry:
        let geomObject = newColladaGeometry()
        geom.add(geomObject)
        x.next()
        geomObject.name = x.attrValue
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

proc parseScene(x: var XmlParser, cs: ColladaScene) = # relationship, matrices, opacity
  while true:
    x.next()
    case x.kind
    of xmlElementOpen:
      case x.elementName:
      of csVisualScene: 
        x.next()
        # sceneNodeID = x.attrValue
        x.next()
        cs.name = x.attrValue()
      of csNode:
        while true:
          x.next()
          case x.kind
          of xmlAttribute:
            case x.elementName:
            of csName: 
              cs.childNodesNames.add(x.attrValue())
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
              cs.childNodesMatrices.add(x.charData())

            of csInstanceMaterial:
              x.next()
              # cs.childNodesMaterialName.add(x.attrValue())
            of csInstanceGeometry:
              x.next()
              # cs.childNodesGeometryName.add(x.attrValue())
            else: discard
          of xmlElementStart:
            case x.elementName:
            of csVisibility:
              x.next()
              cs.childNodesAlpha.add(parseFloat(x.charData()))
            else: discard
          of xmlElementEnd:
            case x.elementName:
            of csNode: break
            else: discard
          of xmlEof: break
          else: discard
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

  let scene = loader.load(fs)
