import streams
import strutils

import asset_types

type
    ObjLoaderObj = object
    ObjLoader* = ref ObjLoaderObj # Loads WafeFront OBJ format for 3D assets

# addVertex : expr = call
# addTexture : expr = call
# addIndex: expr = call
# ret void / bool / exception
template loadMeshData*(loader: ObjLoader, s: Stream, addVertex: expr, addTexture: expr, addFace: expr): expr =
    ## Loads mesh data from stream defined in streams module of
    ## standard library.
    var
        line: string = ""
    while s.readLine(line):
        # Parse line
        line = line.strip()
        let components = line.split()

        if components.len() == 0:
            continue
        elif components[0] == "#":  # Comment
            continue
        elif components[0] == "v":  # Vertex data
            addVertex(parseFloat(components[1]), parseFloat(components[2]), parseFloat(components[3]))
        elif components[0] == "vt": # Vertex Texture data
            addTexture(parseFloat(components[1]), parseFloat(components[2]), parseFloat(components[3]))
        elif components[0] == "vn": # Vertext Normals data
            # TODO: implment vertex normals support
            continue
        elif components[0] == "f":
            if line.count("/") == 0:  # Only vertices in face data
                addFace(parseInt(components[1]), parseInt(components[2]), parseInt(components[3]), 0, 0, 0, 0, 0, 0)
                continue
            elif line.count("/") >= 3:  # Vertex and Texture data in face data
                let
                    block_1 = components[1].split("/")
                    block_2 = components[2].split("/")
                    block_3 = components[3].split("/")
                    vi_0 = parseInt(block_1[0])
                    vi_1 = parseInt(block_2[0])
                    vi_2 = parseInt(block_3[0])
                    ti_0 = parseInt(block_1[1])
                    ti_1 = parseInt(block_2[1])
                    ti_2 = parseInt(block_3[1])
                addFace(vi_0, vi_1, vi_2, ti_0, ti_1, ti_2, 0, 0, 0)
            if line.count("/") == 6:  # Vertex, Texture, and Normals data in face data
                # TODO: implement vertex normals support
                continue

template loadMeshData*(loader: ObjLoader, data: pointer, addVertex: expr, addTexture: expr, addFace: expr): expr =
    ## Loads mesh data from given pointer as a source, and a size
    ## of data provided with pointer.
    let s = newStringStream(`$`(cast[cstring](data)))
    return loadMeshData(loader, s, addVertex, addTexture, addFace)

proc loadMeshData*(loader: ObjLoader, f: File, addVertex: expr, addTexture: expr, addFace: expr): expr =
    ## Loads mesh data from file
    let s = newFileStream(f)
    return loadMeshData(loader, s, addVertex, addTexture, addFace)

proc loadMeshData*(loader: ObjLoader, data: string, addVertex: expr, addTexture: expr, addFace: expr): expr =
    ## Loads mesh data from string
    let s = newStringStream(data)
    return loadMeshData(loader, s, addVertex, addTexture, addFace)


when (isMainModule):
    ## Testing OBjLoader:
    ## - Load Mesh Data on sample OBJ teapot model without textures
    let loader: ObjLoader = new(ObjLoaderObj)
    let f = open("teapot.obj")
    let fs = newFileStream(f)

    proc addVertex(x, y, z: float) =
        echo "Vertex: ", x, " ", y, " ", z

    proc addTexture(u, v, w: float) =
        echo "Texture: ", u, v, w

    proc addFace(vi0, vi1, vi2, ti0, ti1, ti2, ni0, ni1, ni2: int) =
        echo "Face: ", vi0, " ", vi1, " ", vi2, " ", ti0, " ", ti1, " ", ti2, " ", ni0, " ", ni1, " ", ni2

    loadMeshData(loader, fs, addVertex, addTexture, addFace)
