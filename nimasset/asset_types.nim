type
    MeshData*[V, F] = ref object of RootObj ## 3D Mesh-related data from *.obj files
        vertices: seq[array[0..2, V]]       ##   - vertices array
        faces: seq[array[0..2, F]]          ##   - faces array (vertices index array)

proc newMeshData*[V, F](verticesCount: Natural, facesCount: Natural): MeshData[V, F] =
    ## MeshData reference type constructor. Takes number of vertices and
    ## number of faces for initializing internal storage.
    result.new
    result.vertices = newSeq[V](verticesCount)
    result.faces = newSeq[F](facesCount)

proc `$`*[V, F](mesh: ref MeshData[V, F]): string =
    ## MeshData toString operator
    return "string rep of meshdata"

when (isMainModule):
    let mesh = MeshData[float32, int32].new
    echo mesh
