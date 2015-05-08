type
    MeshData*[V, F] = ref object of RootObj
        vertices: seq[array[0..2, V]]
        faces: seq[array[0..2, F]]

proc newMeshData*[V, F](verticesCount: Natural, facesCount: Natural): MeshData[V, F] =
    result.new
    result.vertices = newSeq[V](verticesCount)
    result.faces = newSeq[F](facesCount)

proc `$`*[V, F](mesh: ref MeshData[V, F]): string =
    return "string rep of meshdata"

when (isMainModule):
    let mesh = MeshData[float32, int32].new
    echo mesh
