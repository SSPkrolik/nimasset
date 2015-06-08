type
    MeshData*[V, F] = ref object of RootObj ## 3D Mesh-related data from *.obj files
        vertices*: seq[array[0..2, V]]       ##   - vertices array
        faces*: seq[array[0..2, F]]          ##   - faces array (vertices index array)


proc newMeshData*[V, F](vertices: seq[array[0..2, V]], faces: seq[array[0..2, F]]): MeshData[V, F] =
    result.new
    result.vertices = vertices
    result.faces = faces

proc newMeshData*[V, F](verticesCount: Natural, facesCount: Natural): MeshData[V, F] =
    ## MeshData reference type constructor. Takes number of vertices and
    ## number of faces for initializing internal storage.
    result.new
    result.vertices = newSeq[array[0..2, V]](verticesCount)
    result.faces = newSeq[array[0..2, F]](facesCount)

proc `$`*[V, F](mesh: MeshData[V, F]): string =
    ## MeshData toString operator
    return "3D Mesh " & " (" & $(mesh.vertexCount) & " vertices, " & $(mesh.faceCount) & " faces)"

proc vertexCount*(mesh: MeshData): Natural =
    return len(mesh.vertices)

proc faceCount*(mesh: MeshData): Natural =
    return len(mesh.faces)

when (isMainModule):
    let mesh = newMeshData[float32, int32](0, 0)
    echo mesh
