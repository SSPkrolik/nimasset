import streams
import parsexml
import times

type
  ErrBadCollada = ref object of Exception

  ColladaLoader* = ref object ## Loads COLLADA (*.dae) format for 3D assets

  UpAxis* = enum
    ## Which axis is considered as up
    X_UP = "X_UP"
    Y_UP = "Y_UP"
    Z_UP = "Z_UP"

  Contributor* = object
    ## Contributor information stored in COLLADA file
    author*: string          ## Author
    authoring_tool*: string  ## Where this asset was created in
    comments*: string        ## Some authoring_tool-related info
    copyright*: string       ## Copyright

  UnitInfo* = object
    ## Which units do we measure distances in the asset
    name: string     ## Unit name
    meter: float     ## How much meters are there in the unit

  Asset* = object
    ## General metainformation on COLLADA asset
    contributor*: Contributor ## Contributor info
    created*: TimeInfo        ## When was the asset created
    modified*: TimeInfo       ## When was the asset last modified
    unit*: UnitInfo           ## Real-world distance units
    up_axis*: UpAxis          ## Which axis is considered as up

  Geometry* = ref object
    vertices*: array[0..2, float]

  ColladaScene* = ref object
    ## Collada Scene represented by a file to load from
    asset: Asset
    geometry: seq[Geometry]

  ColladaContext = object
    section: string

const
  csNone  = ""
  csAsset = "asset"

proc load*(loader: ColladaLoader, s: Stream): ColladaScene =
  ## Loads COLLADA data into Nim objects.
  var x: XmlParser
  x.open(s, "")
  x.next()
  result.new
  var cc = ColladaContext(section: csNone)
  while true:
    case x.kind
    of xmlElementStart:
      case x.elementName
      of csAsset:
        if cc.section == csNone:
          cc.section = csAsset
        else:
          raise ErrBadCollada.new
      else:
        break
    else:
      break

when isMainModule and not defined(js):
  let
    f = open("cube.dae")
    fs = newFileStream(f)
    loader = ColladaLoader.new

  let scene = loader.load(fs)
