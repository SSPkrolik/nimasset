import types

proc loadWithPointer[V, F](data: pointer, size: Natural): MeshData =
    result.new
    result.vertices = newSeq[V](size /% 3)
    result.faces = newSeq[F](size /% 3 - 1)


when (isMainModule):
    echo "!"
