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
template loadMeshData*(loader: ObjLoader, s: Stream, addVertex: untyped, addTexture: untyped, addNormal: untyped, addFace: untyped) =
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
            addNormal(parseFloat(components[1]), parseFloat(components[2]), parseFloat(components[3]))
        elif components[0] == "f":
            let comnponentsCount = components[1].count("/") + 1
            if comnponentsCount == 1:  # Only vertices in face data
                addFace(parseInt(components[1]), parseInt(components[2]), parseInt(components[3]), 0, 0, 0, 0, 0, 0)
                continue
            elif comnponentsCount >= 2:  # Vertex, Normal and Texture data in face data
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
                var
                    ni0 = 0
                    ni1 = 0
                    ni2 = 0

                if comnponentsCount >= 3:
                    ni0 = parseInt(block_1[2])
                    ni1 = parseInt(block_2[2])
                    ni2 = parseInt(block_3[2])
                addFace(vi_0, vi_1, vi_2, ti_0, ti_1, ti_2, ni0, ni1, ni2)

template loadMeshData*(loader: ObjLoader, s: Stream, addVertex: untyped, addTexture: untyped, addFace: untyped) =
    template addNormal(x, y, z: float32) = discard
    loadMeshData(loader, s, addVertex, addTexture, addNormal, addFace)

template loadMeshData*(loader: ObjLoader, data: pointer, addVertex: untyped, addTexture: untyped, addNormal: untyped, addFace: untyped) =
    ## Loads mesh data from given pointer as a source, and a size
    ## of data provided with pointer.
    loadMeshData(loader, newStringStream(`$`(cast[cstring](data))), addVertex, addTexture, addNormal, addFace)

when not defined(js):
    template loadMeshData*(loader: ObjLoader, f: File, addVertex: untyped, addTexture: untyped, addNormal: untyped, addFace: untyped) =
        ## Loads mesh data from file
        loadMeshData(loader, newFileStream(f), addVertex, addTexture, addNormal, addFace)

template loadMeshData*(loader: ObjLoader, data: string, addVertex: untyped, addTexture: untyped, addNormal: untyped, addFace: untyped) =
    ## Loads mesh data from string
    loadMeshData(loader, newStringStream(data), addVertex, addTexture, addNormal, addFace)


when isMainModule and not defined(js):
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
