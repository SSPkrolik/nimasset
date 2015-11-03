import streams
import parsexml
import times

type
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

  Geometry = ref object
    vertices: array[0..2, float]

  ColladaScene* = ref object
    ## Collada Scene represented by a file to load from
    asset: Asset
    geometry: seq[Geometry]

template load*(loader: ColladaLoader, s: Stream): expr =
  ## The very low-level way to load COLLADA data into application.
  var x: XmlParser
  x.open(s, "")
  x.next()
  while true:
    case x.kind
    of xmlElementStart:
      break
    else:
      break

when isMainModule and not defined(js):
  let
    f = open("cube.dae")
    fs = newFileStream(f)
    loader = ColladaLoader.new

  loader.load(fs)
