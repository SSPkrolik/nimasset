nimasset - assets loading library for Nim applications
======================================================

NimAsset is a library containing generic low- and high-level routines and
objects for loading assets within Nim applications.

Supported asset formats:

  * `.obj` - low-level loader of WaveFront OBJ files containing 3d models
  * `.dae` - Open COLLADA v. 1.4 scene loader with support of loading:
    * geometry
    * materials
    * animation
    * lighting

## Loading `obj` files

OBJ files loader provides extremely low-level API that allows client code
to cut in loading process, and perform flexible in-memory layout of 3D
object data.

Here's an example that just print parsed data into `stdout`.

```nim
let
    loader: ObjLoader = new(ObjLoaderObj)
    f = open("teapot.obj")
    fs = newFileStream(f)

proc addVertex(x, y, z: float) =
    echo "Vertex: ", x, " ", y, " ", z

proc addTexture(u, v, w: float) =
    echo "Texture: ", u, v, w

proc addFace(vi0, vi1, vi2, ti0, ti1, ti2, ni0, ni1, ni2: int) =
    echo "Face: ", vi0, " ", vi1, " ", vi2, " ", ti0, " ", ti1, " ", ti2, " ", ni0, " ", ni1, " ", ni2

loadMeshData(loader, fs, addVertex, addTexture, addFace)
```

## Loading `dae` files

COLLADA files allow complex scenes to be saved in a single file, so it loads
scene data into in-memory objects.

```nim
let
  f = open("cube.dae")
  fs = newFileStream(f)
  loader = ColladaLoader.new

let scene = loader.load(fs)
```
