# Layout Algorithms Reference

Choosing the right layout algorithm is the single most important decision for graph visualisation. **Wrong algorithm = messy graph**, regardless of styling.

## Decision Tree

```
What is your data structure?
│
├─ TREE (strict hierarchy, single parent per node)
│   └─ Use: Dagre, ELK layered, or D3-tree
│       ├─ Dagre: Simple, fast, good defaults
│       ├─ ELK: More control, better edge routing
│       └─ D3-tree: Best for radial/dendrogram layouts
│
├─ DAG (directed acyclic, multiple parents allowed)
│   └─ Use: Dagre, ELK layered
│       ├─ Dagre: Handles DAGs well, may need rankdir tuning
│       └─ ELK: Superior for complex DAGs, port constraints
│
├─ CYCLIC GRAPH (has loops/cycles)
│   └─ Use: Force-directed (D3-force, Cola.js)
│       ├─ D3-force: Most flexible, requires tuning
│       └─ Cola.js: Constraint-based, better for clusters
│
└─ MIXED/UNKNOWN
    └─ Start with force-directed, refine based on results
```

## Algorithm Comparison

| Algorithm | Best For | Node Limit | Edge Crossing | Deterministic |
|-----------|----------|------------|---------------|---------------|
| Dagre | Trees, DAGs, flowcharts | ~500 | Low | Yes |
| ELK layered | Complex DAGs, ports | ~1000 | Very low | Yes |
| D3-force | Networks, clusters | ~500* | Medium | No |
| Cola.js | Constrained layouts | ~300 | Medium | No |
| D3-tree | Trees, radial | ~1000 | None | Yes |
| Graphviz/DOT | Any, especially large | ~10000 | Very low | Yes |

*Force-directed performance depends heavily on tuning

## Dagre

**Best for:** Flowcharts, org charts, dependency graphs, state machines

### Key Options

```typescript
dagreGraph.setGraph({
  rankdir: 'TB',     // TB, BT, LR, RL
  align: undefined,  // UL, UR, DL, DR (node alignment within rank)
  nodesep: 50,       // Horizontal separation (in TB/BT)
  ranksep: 100,      // Separation between ranks
  edgesep: 10,       // Minimum edge separation
  acyclicer: 'greedy', // How to handle cycles: 'greedy' or undefined
  ranker: 'network-simplex', // 'network-simplex', 'tight-tree', 'longest-path'
});
```

### Tuning Guide

**Problem: Nodes too close together**
```typescript
nodesep: 80,   // Increase from default 50
ranksep: 150,  // Increase from default 50
```

**Problem: Wide graphs, want more vertical**
```typescript
rankdir: 'TB',
ranker: 'tight-tree',  // Tends to produce taller, narrower graphs
```

**Problem: Cycles causing layout issues**
```typescript
acyclicer: 'greedy',  // Temporarily removes cycles for layout
```

**Problem: Edges crossing unnecessarily**
```typescript
// Dagre has limited edge crossing optimisation
// Consider ELK for edge-heavy graphs
```

### Rank Assignment

Control vertical position explicitly:

```typescript
// Force node to specific rank
dagreGraph.setNode('nodeId', {
  width: 100,
  height: 50,
  rank: 2,  // 0-indexed, higher = lower in TB
});
```

## ELK (Eclipse Layout Kernel)

**Best for:** Complex DAGs, flowcharts with ports, when Dagre isn't cutting it

### Algorithms

```typescript
// Layered (most common, like Dagre but better)
'elk.algorithm': 'layered'

// Force-directed
'elk.algorithm': 'force'

// Box layout (for nested graphs)
'elk.algorithm': 'box'

// Stress (good for networks)
'elk.algorithm': 'stress'

// Random (starting point for force)
'elk.algorithm': 'random'
```

### Key Options for Layered

```typescript
const layoutOptions = {
  'elk.algorithm': 'layered',
  'elk.direction': 'DOWN',  // DOWN, UP, LEFT, RIGHT

  // Spacing
  'elk.spacing.nodeNode': '50',
  'elk.layered.spacing.nodeNodeBetweenLayers': '100',
  'elk.spacing.edgeNode': '25',
  'elk.spacing.edgeEdge': '15',

  // Edge routing
  'elk.layered.edgeRouting': 'ORTHOGONAL',  // POLYLINE, ORTHOGONAL, SPLINES

  // Cycle handling
  'elk.layered.cycleBreaking.strategy': 'GREEDY',

  // Node placement
  'elk.layered.nodePlacement.strategy': 'NETWORK_SIMPLEX',

  // Crossing minimisation
  'elk.layered.crossingMinimization.strategy': 'LAYER_SWEEP',
};
```

### Port Constraints

ELK's killer feature — control exactly where edges connect:

```typescript
const elkNode = {
  id: 'node1',
  width: 200,
  height: 100,
  ports: [
    { id: 'port1', properties: { 'port.side': 'SOUTH', 'port.index': 0 } },
    { id: 'port2', properties: { 'port.side': 'SOUTH', 'port.index': 1 } },
    { id: 'port3', properties: { 'port.side': 'NORTH' } },
  ],
  properties: {
    'portConstraints': 'FIXED_SIDE',  // FIXED_ORDER, FIXED_POS, FIXED_RATIO
  },
};

const elkEdge = {
  id: 'edge1',
  sources: ['node1/port1'],  // Connect to specific port
  targets: ['node2/port3'],
};
```

## D3-Force

**Best for:** Network graphs, social graphs, clustering visualisations, organic layouts

### Core Forces

```typescript
const simulation = d3.forceSimulation(nodes)
  // Pull connected nodes together
  .force('link', d3.forceLink(edges)
    .id(d => d.id)
    .distance(100)      // Target link length
    .strength(0.5))     // How strongly to enforce distance

  // Push all nodes apart
  .force('charge', d3.forceManyBody()
    .strength(-300)     // Negative = repel
    .distanceMax(500))  // Limit range for performance

  // Pull everything toward center
  .force('center', d3.forceCenter(width / 2, height / 2))

  // Prevent overlap
  .force('collision', d3.forceCollide()
    .radius(d => d.radius + 10));
```

### Tuning Guide

**Problem: Nodes fly off screen**
```typescript
.force('charge', d3.forceManyBody().strength(-100))  // Reduce repulsion
.force('center', d3.forceCenter(cx, cy).strength(0.1))  // Add centering
```

**Problem: Nodes overlap**
```typescript
.force('collision', d3.forceCollide()
  .radius(d => Math.max(d.width, d.height) / 2 + 20)
  .strength(1))
```

**Problem: Clusters too spread out**
```typescript
// Add cluster force
.force('cluster', forceCluster()
  .centers(clusterCenters)
  .strength(0.5))
```

**Problem: Layout never settles**
```typescript
simulation
  .alphaDecay(0.02)     // Faster cooling (default 0.0228)
  .velocityDecay(0.4)   // More friction (default 0.4)
  .alphaMin(0.001);     // Stop earlier
```

### Integration with React Flow

```typescript
function useForceLayout(nodes, edges) {
  const simulationRef = useRef(null);

  useEffect(() => {
    const simulation = d3.forceSimulation(nodes)
      .force('link', d3.forceLink(edges).id(d => d.id))
      .force('charge', d3.forceManyBody().strength(-200))
      .force('collision', d3.forceCollide(50));

    simulation.on('tick', () => {
      // Update React Flow nodes with new positions
      setNodes(nodes.map(node => ({
        ...node,
        position: { x: node.x, y: node.y },
      })));
    });

    simulationRef.current = simulation;

    return () => simulation.stop();
  }, [/* careful with dependencies */]);

  return simulationRef;
}
```

**Warning:** Force simulation ticks many times. Batch updates or use requestAnimationFrame.

## D3-Tree / D3-Hierarchy

**Best for:** Pure trees, org charts, file trees, radial layouts

```typescript
import * as d3 from 'd3';

// Convert flat nodes to hierarchy
const root = d3.stratify()
  .id(d => d.id)
  .parentId(d => d.parentId)
  (nodes);

// Standard tree layout
const treeLayout = d3.tree()
  .size([width, height])
  .separation((a, b) => a.parent === b.parent ? 1 : 2);

// Radial tree layout
const radialLayout = d3.tree()
  .size([2 * Math.PI, radius])
  .separation((a, b) => (a.parent === b.parent ? 1 : 2) / a.depth);

treeLayout(root);

// Access positions
root.descendants().forEach(node => {
  console.log(node.x, node.y);  // Computed positions
});
```

## Performance Comparison

| Operation | Dagre | ELK | D3-Force | D3-Tree |
|-----------|-------|-----|----------|---------|
| 100 nodes | <10ms | <50ms | ~100ms* | <5ms |
| 500 nodes | ~50ms | ~200ms | ~1s* | <20ms |
| 1000 nodes | ~200ms | ~500ms | slow* | ~50ms |

*Force layout runs continuously; times are for stabilisation

## When to Abandon Auto-Layout

Sometimes auto-layout is the wrong tool:

1. **User-defined positions matter** — Let users drag, persist positions
2. **Domain-specific constraints** — Map coordinates, timeline positions, etc.
3. **Mixed layout regions** — Auto-layout one section, manual another
4. **Performance critical** — Pre-compute layout server-side, serve static positions

Hybrid approach:
```typescript
// Auto-layout only new nodes
function addNodeWithLayout(newNode, existingNodes, edges) {
  const tempNodes = [...existingNodes, { ...newNode, position: { x: 0, y: 0 } }];
  const { nodes } = getLayoutedElements(tempNodes, edges);

  // Keep existing positions, only place new node
  return nodes.map(n =>
    existingNodes.find(e => e.id === n.id) ?? n
  );
}
```
