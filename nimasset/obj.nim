import streams
import strutils

import asset_types

type
    ObjLoaderObj = object
    ObjLoader* = ref ObjLoaderObj # Loads WafeFront OBJ format for 3D assets

proc loadMeshData*[V, F](loader: ObjLoader, s: Stream): MeshData[V, F] =
    ## Loads mesh data from stream defined in streams module of
    ## standard library.
    var
        line: string = ""
        vertices: seq[array[0..2, V]] = @[]
        faces: seq[array[0..2, F]] = @[]

    while s.readLine(line):
        line = line.strip()
        if line.startsWith("#"):
            continue

        let components = line.split()
        if components.len() == 0:
            continue

        case components[0]:
        of "v":
            vertices.add([
                cast[V](parseFloat(components[1])),
                cast[V](parseFloat(components[2])),
                cast[V](parseFloat(components[3]))
            ])
        of "f":
            discard # TODO: parse faces
        else:
            echo("[W] Not parsed: " & line)
            continue # TODO: load something that was not parsed

    result.new
    result.vertices = vertices
    result.faces = faces


proc loadMeshData*[V, F](loader: ObjLoader, data: pointer, size: Natural): MeshData[V, F] =
    ## Loads mesh data from given pointer as a source, and a size
    ## of data provided with pointer.
    let s = newStringStream(`$`(cast[cstring](data)))
    return loadMeshData[V, F](loader, s)

proc loadMeshData*[V, F](loader: ObjLoader, f: File): MeshData[V, F] =
    ## Loads mesh data from file
    let s = newFileStream(f)
    return loadMeshData[V, F](loader, s)

proc loadMeshData*[V, F](loader: ObjLoader, data: string): MeshData[V, F] =
    ## Loads mesh data from string
    let stream = newStringStream(data)
    result = newMeshData[V, F](0, 0)

when (isMainModule):
    let loader: ObjLoader = new(ObjLoaderObj)
    let f = open("teapot.obj")
    let mesh = loadMeshData[float32, int32](loader, f)
    echo mesh
    f.close()
