type
    MeshDataObj*[V, F] = object
        vertices: seq[array[0..2, V]]
        faces: seq[array[0..2, F]]

    MeshData*[V, F] = ref MeshDataObj[V, F]


proc newMeshData*[V, F](verticesCount: Natural, facesCount: Natural): MeshData[V, F] =
    result.new
    result.vertices = newSeq[V](verticesCount /% 3)
    result.faces = newSeq[F](facesCount /% 3 - 1)

proc `$`*[V, F](mesh: MeshDataObj[V, F]): string =
    return "string rep of meshdata object"

proc `$`*[V, F](mesh: ref MeshData[V, F]): string =
    return "string rep of meshdata"


when (isMainModule):
    let meshObj = MeshDataObj[float32, int32]()
    echo meshObj
    let mesh = MeshData[float32, int32].new
    echo mesh
