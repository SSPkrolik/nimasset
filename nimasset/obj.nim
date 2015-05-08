import streams

import asset_types


proc loadMeshData*[V, F](af: AssetFormat, data: pointer, size: Natural): MeshData[V, F] =
    ## Loads mesh data from given pointer as a source, and a size
    ## of data provided with pointer.
    result = newMeshData[V, F](0, 0)

proc loadMeshData*[V, F](af: AssetFormat, s: FileStream): MeshData[V, F] =
    ## Loads mesh data from file stream
    result = newMeshData[V, F](0, 0)

proc loadMeshData*[V, F](af: AssetFormat, f: File): MeshData[V, F] =
    ## Loads mesh data from file
    result = newMeshData[V, F](0, 0)

proc loadMeshData*[V, F](af: AssetFormat, data: string): MeshData[V, F] =
    ## Loads mesh data from string
    result = newMeshData[V, F](0, 0)

when (isMainModule):
    let mesh = loadMeshData[float32, int32](ObjFormat, "some data")
    echo mesh
