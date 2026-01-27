# Graph Patterns Reference

Common visualisation patterns and when to use them.

## Pattern Selection Guide

| Pattern | Data Shape | Use Case | Layout Algorithm |
|---------|-----------|----------|------------------|
| Tree | Strict hierarchy | Org charts, file systems | Dagre TB, D3-tree |
| DAG | Multi-parent hierarchy | Dependencies, workflows | Dagre, ELK layered |
| Flowchart | Sequential with branches | Processes, state machines | Dagre LR/TB, ELK |
| Network | Arbitrary connections | Social graphs, knowledge | D3-force, Cola.js |
| Radial | Hierarchy from center | Mind maps, exploration | D3-tree radial |
| Matrix | Dense connections | Heatmaps, relationships | No layout needed |
| Sankey | Flow quantities | Data flow, budgets | D3-sankey |
| Timeline | Time-ordered | History, project plans | Custom x-axis |

## Tree Layouts

### Standard Tree

```
        Root
       /    \
      A      B
     / \      \
    C   D      E
```

**When to use:** Org charts, file systems, taxonomies, decision trees

**Configuration:**

```typescript
// Dagre
dagreGraph.setGraph({
  rankdir: 'TB',  // Top to bottom
  nodesep: 50,
  ranksep: 80,
});

// React Flow setup
const defaultEdgeOptions = {
  type: 'smoothstep',
  animated: false,
};
```

### Horizontal Tree (LR)

```
Root ─┬─ A ─┬─ C
      │     └─ D
      └─ B ─── E
```

**When to use:** Mind maps, menu structures, when horizontal space > vertical

```typescript
dagreGraph.setGraph({
  rankdir: 'LR',
  nodesep: 30,   // Tighter vertical
  ranksep: 120,  // More horizontal
});
```

### Radial Tree

Nodes arranged in circles around center:

```typescript
import * as d3 from 'd3';

const root = d3.hierarchy(data);
const treeLayout = d3.tree()
  .size([2 * Math.PI, radius])
  .separation((a, b) => (a.parent === b.parent ? 1 : 2) / a.depth);

treeLayout(root);

// Convert polar to Cartesian
root.descendants().forEach(d => {
  d.x_cart = d.y * Math.cos(d.x - Math.PI / 2);
  d.y_cart = d.y * Math.sin(d.x - Math.PI / 2);
});
```

**When to use:** Exploration interfaces, when showing distance from center matters

## DAG (Directed Acyclic Graph)

```
    A ─────┐
    │      │
    ▼      ▼
    B      C
    │      │
    └──▶ D ◀┘
```

**When to use:** Build systems, dependency graphs, data pipelines, Git history

**Challenges:**
- Nodes can have multiple parents
- Need to minimise edge crossings

**Configuration:**

```typescript
// Dagre handles DAGs automatically
dagreGraph.setGraph({
  rankdir: 'TB',
  ranker: 'network-simplex',  // Best for DAGs
});

// ELK for complex DAGs
{
  'elk.algorithm': 'layered',
  'elk.layered.crossingMinimization.strategy': 'LAYER_SWEEP',
}
```

## Flowcharts / Process Diagrams

```
[Start] → [Decision] →─Yes─→ [Process A] → [End]
              │
              No
              │
              ▼
         [Process B] ──────────────────────┘
```

**When to use:** Business processes, state machines, algorithms, BPMN

**Key elements:**
- Decision nodes (diamond shape)
- Start/end nodes (rounded/circles)
- Process nodes (rectangles)
- Directional edges with labels

```typescript
// Node types
const nodeTypes = {
  process: ProcessNode,
  decision: DiamondNode,
  start: CircleNode,
  end: CircleNode,
};

// Decision nodes need multiple outgoing handles
function DiamondNode({ data }) {
  return (
    <div className="diamond">
      <Handle type="target" position={Position.Top} />
      <div>{data.label}</div>
      <Handle type="source" position={Position.Right} id="yes" />
      <Handle type="source" position={Position.Bottom} id="no" />
    </div>
  );
}

// Edge labels
const edge = {
  id: 'e1',
  source: 'decision1',
  sourceHandle: 'yes',
  target: 'processA',
  label: 'Yes',
  labelStyle: { fill: '#333', fontWeight: 700 },
};
```

## Network Graphs

No inherent hierarchy; nodes connected arbitrarily:

```
    A ─── B
   /│\    │
  C─┼─D───E
    │   \ │
    F ─── G
```

**When to use:** Social networks, knowledge graphs, entity relationships

**Force-directed is usually best:**

```typescript
const simulation = d3.forceSimulation(nodes)
  .force('link', d3.forceLink(edges).id(d => d.id).distance(100))
  .force('charge', d3.forceManyBody().strength(-300))
  .force('center', d3.forceCenter(width / 2, height / 2))
  .force('collision', d3.forceCollide(nodeRadius + 10));
```

**Clustering networks:**

```typescript
// Group related nodes
.force('cluster', forceCluster()
  .centers(d => clusterCenters[d.group])
  .strength(0.7))
```

## Mind Maps

Radial expansion from central concept:

```
                ┌─ Subtopic 1.1
         Topic 1 ┤
        /       └─ Subtopic 1.2
Central
        \       ┌─ Subtopic 2.1
         Topic 2 ┤
                └─ Subtopic 2.2
```

**When to use:** Brainstorming, concept exploration, documentation structure

**Implementation approach:**
1. Radial tree layout from center
2. Alternate left/right for balance
3. Curved edges for organic feel

```typescript
// Alternate sides for balance
root.children.forEach((child, i) => {
  child._side = i % 2 === 0 ? 'right' : 'left';
});

// Position based on side
const x = node._side === 'right' ? centerX + offset : centerX - offset;
```

## Data Flow / Pipeline

```
[Source A] ─┬─→ [Transform 1] ─→ [Join] ─→ [Output]
[Source B] ─┘                      ↑
                                   │
[Source C] ─→ [Transform 2] ───────┘
```

**When to use:** ETL pipelines, data processing, streaming architectures

**Key patterns:**
- Clear left-to-right flow
- Multiple inputs/outputs per node
- Port-based connections

```typescript
// Use ELK with ports for precise connections
const node = {
  id: 'transform1',
  ports: [
    { id: 'in', properties: { 'port.side': 'WEST' } },
    { id: 'out-success', properties: { 'port.side': 'EAST', 'port.index': 0 } },
    { id: 'out-error', properties: { 'port.side': 'EAST', 'port.index': 1 } },
  ],
};
```

## State Machines

```
          ┌─────────────┐
          │             │
          ▼             │
[Idle] → [Loading] → [Success]
  │                     │
  │         ┌───────────┘
  ▼         ▼
[Error] ← ──┘
```

**When to use:** UI state, game states, protocol diagrams, business workflows

**Challenges:**
- Self-loops (state can transition to itself)
- Bidirectional transitions

```typescript
// Handle self-loops
const edges = states.flatMap(state =>
  state.transitions.map(t => ({
    id: `${state.id}-${t.target}`,
    source: state.id,
    target: t.target,
    type: state.id === t.target ? 'selfLoop' : 'smoothstep',
    label: t.event,
  }))
);
```

## Hybrid Layouts

Combine patterns for complex visualisations:

### Hierarchical with Clusters

```typescript
// Layout clusters separately, then arrange clusters
const clusters = groupBy(nodes, 'cluster');

const clusterPositions = getLayoutedElements(
  Object.keys(clusters).map(id => ({ id, ...clusterDimensions })),
  clusterEdges,
  'TB'
);

// Layout nodes within each cluster
Object.entries(clusters).forEach(([clusterId, clusterNodes]) => {
  const { nodes: positioned } = getLayoutedElements(clusterNodes, internalEdges);
  // Offset by cluster position
});
```

### Timeline with Swimlanes

```
         ─────────────────────────────────▶ Time
Lane A │  [Task 1]────[Task 2]
Lane B │       [Task 3]──────────[Task 4]
Lane C │  [Task 5]
```

```typescript
// Y position from lane, X position from time
const getPosition = (task) => ({
  x: timeScale(task.startDate),
  y: laneIndex[task.lane] * LANE_HEIGHT,
});
```

## Pattern Anti-Patterns

**Don't do these:**

1. **Force-directed for hierarchies** — Trees look awful with force layouts

2. **Tree layout for networks** — Dagre will break or produce garbage

3. **Mixing layout algorithms** — Don't Dagre half and force the other half

4. **Ignoring data shape** — The algorithm must match your data structure

5. **Overcrowding** — If you can't read it, it's not a visualisation

6. **Rainbow edges** — Color should encode meaning, not decoration
