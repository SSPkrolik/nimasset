import streams

import asset_types


proc loadMeshData*[V, F](data: pointer, size: Natural): MeshData =
    ## Loads mesh data from given pointer as a source, and a size
    ## of data provided with pointer.
    result = newMeshData[V, F](size /% 3, 0)

proc loadMeshData*[V, F](s: FileStream): MeshData =
    ## Loads mesh data from file stream
    result = newMeshData[V, F](0, 0)

proc loadMeshData*[V, F](f: File): MeshData =
    ## Loads mesh data from file
    result = newMeshData[V, F](0, 0)

proc loadMeshData*[V, F](data: string): MeshData =
    ## Loads mesh data from string
    result = newMeshData[V, F](len(data) /% 3, 0)


when (isMainModule):
    echo "!"
