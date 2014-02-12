require('array-sugar')

class Graph
    constructor: () ->
        @nodes = []
        @edges = []
    
    addNode: (node) ->
        return if (@nodes.findOne (n) -> node.equals n)?
        @nodes.push node
        
        
    addEdge: (edge) ->
        return if (@edges.findOne (e) -> edge.equals e)?
        @addNode edge.n1
        @addNode edge.n2
        @edges.push edge
        
    print: () ->
        res = "graph network {\n"
        @nodes.forEach (node) ->
            res += "\t" + node.print() + ";\n"
        @edges.forEach (edge) ->
            res += "\t" + edge.print() + ";\n"
        res += "}"
        return res
        
    
class Node
    constructor: (@id, @capacity) ->
        
    equals: (node) ->
        node.id is @id
    
    print: () ->
        '"' + @id + '(' + @capacity + ')"'
    
class Edge
    constructor: (@n1, @n2) ->
    
    equals: (edge) ->
        (edge.n1.equals @n1) and (edge.n2.equals @n2) or
        (edge.n1.equals @n2) and (edge.n2.equals @n1)
    
    print: () ->
        @n1.print() + " -- " + @n2.print()

        
module.exports =
    Graph: Graph
    Node: Node
    Edge: Edge
###        
g = new Graph()

n0 = new Node("p0", 4)
n3 = new Node("p3", 6)
n4 = new Node("p4", 6)
n6 = new Node("p6", 3)
n8 = new Node("p8", 1)
n1 = new Node("p1", 8)
n5 = new Node("p5", 7)
n7 = new Node("p7", 5)
n9 = new Node("p9", 2)


e1 = new Edge(n1, n0)
e2 = new Edge(n1, n3)
e3 = new Edge(n1, n4)
e4 = new Edge(n1, n5)
e5 = new Edge(n1, n6)
e6 = new Edge(n1, n7)
e7 = new Edge(n1, n8)
e8 = new Edge(n1, n9)

g.addEdge(e1)
g.addEdge(e2)
g.addEdge(e3)
g.addEdge(e4)
g.addEdge(e5)
g.addEdge(e6)
g.addEdge(e7)
g.addEdge(e8)

console.log g.print()
###