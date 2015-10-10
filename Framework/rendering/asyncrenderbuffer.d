module rendering.asyncrenderbuffer;
import graphics;

struct AsyncRenderBuffer(Vertex)
{
	private VAO!Vertex vao;
	private VBO vbo;
	private IBO ibo;

	private Vertex* mappedPtr;
	private uint*   mappedIndexPtr;

	private const int batchSize, batchCount;
	private int mappedStart;
	private int elements;
	private int numVertices;

	this(U)(size_t batchSize, size_t batchCount, ref Program!(U, Vertex) program)
	{
		this.elements   = this.mappedStart = 0;
		this.batchSize  = batchSize;
		this.batchCount = batchCount; 

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vbo.bind();
		this.vbo.initialize(Vertex.sizeof * batchSize * batchCount);

		this.ibo = IBO.create(BufferHint.streamDraw);
		this.ibo.bind();
		this.ibo.initialize(batchSize * 12 * batchCount);

		this.vao = VAO!Vertex.create();
		setupVertexBindings(vao, program, vbo, &ibo);

		vao.unbind();
	}

	void addItems(Vertex[] vertices, uint[] indecies)
	{
		assert(mappedPtr !is null);
		assert(elements + indecies.length <= (mappedStart + batchSize) * 3);
		assert(numVertices + vertices.length < mappedStart + batchSize);

		mappedPtr[0 .. vertices.length] = vertices[];
		mappedPtr += vertices.length;

		mappedIndexPtr[0 .. indecies.length] = indecies[] + numVertices;
		mappedIndexPtr += indecies.length;

		elements += cast(int)indecies.length;
		numVertices += cast(int)vertices.length;
	}

	void map()
	{
		assert(mappedPtr is null, "Can only begin rendering if we are not already rendering!");

		vbo.bind();
		mappedPtr = vbo.mapRange!Vertex(mappedStart,
										batchSize, 
										BufferRangeAccess.unsynchronizedWrite);

		ibo.bind();
		mappedIndexPtr = ibo.mapRange!uint(mappedStart * 3,
										   batchSize * 3,
										   BufferRangeAccess.unsynchronizedWrite);
	}

	int unmap()
	{
		vbo.bind();
		vbo.unmapBuffer();
		mappedPtr = null;

		ibo.bind();
		ibo.unmapBuffer();
		mappedIndexPtr = null;

		int start  = mappedStart * 3;
		mappedStart = (mappedStart + batchSize) % (batchSize * batchCount);
		elements    = mappedStart * 3; 
		numVertices = mappedStart;

		return start;
	}

	void render(U)(uint start, uint count, ref Program!(U,Vertex) program)
	{
		drawElements!(uint, Vertex, U)(this.vao, program, PrimitiveType.triangles, start, count);
	}
}

struct SubBufferRenderBuffer(Vertex)
{
	private VAO!Vertex vao;
	private VBO vbo;
	private IBO ibo;

	private int batchSize;
	private int numIndices;
	private int numVertices;

	private ushort[] indices;
	private Vertex[] vertices;

	this(A, U)(ref A all, uint batchSize,  ref Program!(U, Vertex) program)
	{
		import allocation;

		this.numIndices = this.numVertices = 0;
		this.batchSize  = batchSize;

		this.indices    = all.allocate!(ushort[])(batchSize * 3);
		this.vertices   = all.allocate!(Vertex[])(batchSize);

		this.vbo = VBO.create(BufferHint.streamDraw);
		this.vbo.bind();
		this.vbo.initialize(cast(uint)(Vertex.sizeof * batchSize));

		this.ibo = IBO.create(BufferHint.streamDraw);
		this.ibo.bind();
		this.ibo.initialize(batchSize * 6);

		this.vao = VAO!Vertex.create();
		setupVertexBindings(vao, program, vbo, &ibo);
		vao.unbind();
	}

	void addItems(Vertex[] vertices, ushort[] indecies)
	{
		assert(numIndices  + indecies.length <= batchSize * 3);
		assert(numVertices + vertices.length <= batchSize);

		this.indices [numIndices  .. numIndices  + indecies.length] = indecies[] + cast(ushort)numVertices;
		this.vertices[numVertices .. numVertices + vertices.length] = vertices[];  

		numIndices   += cast(int)indecies.length;
		numVertices  += cast(int)vertices.length;
	}

	void pushToGL()
	{
		vbo.bind();
		vbo.bufferSubData(vertices[0 .. numVertices], 0);

		ibo.bind();
		ibo.bufferSubData(indices[0 .. numIndices], 0);
		
		numIndices  = 0;
		numVertices = 0;
	}

	void render(U)(uint start, uint count, ref Program!(U,Vertex) program)
	{
		drawElements!(ushort, Vertex, U)(this.vao, program, PrimitiveType.triangles, start, count);
	}
}	