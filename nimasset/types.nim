type
    MeshDataObj*[V, F] = object
        vertices: seq[array[0..2, V]]
        faces: seq[array[0..2, F]]

    MeshData*[V, F] = ref MeshDataObj[V, F]
