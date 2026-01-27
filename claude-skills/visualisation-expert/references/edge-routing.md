# Edge Routing Reference

Edge routing determines how lines connect nodes. Bad edge routing creates visual chaos even with perfect node layout.

## Edge Types

### React Flow Built-in Types

```typescript
type EdgeType = 'default' | 'straight' | 'step' | 'smoothstep' | 'bezier';
```

| Type | Best For | Notes |
|------|----------|-------|
| `default` | General use | Bezier curve, follows handle direction |
| `straight` | Simple diagrams | Direct line, can cross through nodes |
| `step` | Flowcharts | Right angles only, orthogonal |
| `smoothstep` | Flowcharts | Rounded corners on steps |
| `bezier` | Organic graphs | Curved, configurable control points |

### Choosing Edge Type by Layout Direction

```typescript
// Top-to-bottom (TB) layouts
const edgeType = 'smoothstep';  // Clean right angles

// Left-to-right (LR) layouts
const edgeType = 'smoothstep';  // Also works well

// Force-directed / network layouts
const edgeType = 'bezier';  // Curves handle arbitrary angles better

// Minimal / schematic diagrams
const edgeType = 'straight';  // When simplicity matters
```

## Handle Positioning

Handles (connection points) are the #1 source of edge routing problems.

### Handle Position Rules

```
Layout Direction → Source Handle → Target Handle
─────────────────────────────────────────────────
TB (top-bottom)  → bottom        → top
BT (bottom-top)  → top           → bottom
LR (left-right)  → right         → left
RL (right-left)  → left          → right
```

### Setting Handles in React Flow

```typescript
// On node definition
const node = {
  id: '1',
  position: { x: 0, y: 0 },
  data: { label: 'Node' },
  sourcePosition: Position.Bottom,  // Where outgoing edges start
  targetPosition: Position.Top,     // Where incoming edges end
};

// Or in custom node component
function CustomNode({ data }) {
  return (
    <div>
      <Handle type="target" position={Position.Top} />
      <div>{data.label}</div>
      <Handle type="source" position={Position.Bottom} />
    </div>
  );
}
```

### Multiple Handles

When nodes have multiple connections:

```typescript
function MultiHandleNode({ data }) {
  return (
    <div className="node">
      {/* Named handles for specific connections */}
      <Handle type="target" position={Position.Top} id="input-1" />
      <Handle type="target" position={Position.Top} id="input-2"
        style={{ left: '75%' }} />

      <div>{data.label}</div>

      <Handle type="source" position={Position.Bottom} id="output-main" />
      <Handle type="source" position={Position.Right} id="output-alt" />
    </div>
  );
}

// Connect to specific handle
const edge = {
  id: 'e1',
  source: 'node1',
  target: 'node2',
  sourceHandle: 'output-main',
  targetHandle: 'input-1',
};
```

## Edge Routing Strategies

### 1. Straight Lines

Simple but causes overlap issues:

```typescript
const edge = { type: 'straight', ...otherProps };
```

**When to use:** Small graphs, schematic diagrams, when crossings are acceptable.

### 2. Orthogonal Routing (Step/Smoothstep)

Right angles only, like circuit diagrams:

```typescript
const edge = { type: 'smoothstep', ...otherProps };
```

**When to use:** Flowcharts, BPMN diagrams, technical schematics.

**Problem:** Default routing may cross through nodes.

**Solution:** Use ELK's orthogonal routing which avoids obstacles:

```typescript
// ELK layout options
{
  'elk.layered.edgeRouting': 'ORTHOGONAL',
  'elk.layered.edgeRouting.selfLoopDistribution': 'EQUALLY',
}
```

### 3. Bezier Curves

Smooth curves with control points:

```typescript
// Custom bezier with control points
import { getBezierPath } from 'reactflow';

function CustomEdge({ sourceX, sourceY, targetX, targetY, ...props }) {
  const [edgePath] = getBezierPath({
    sourceX,
    sourceY,
    sourcePosition: Position.Bottom,
    targetX,
    targetY,
    targetPosition: Position.Top,
    curvature: 0.25,  // Adjust curve intensity
  });

  return <path d={edgePath} {...props} />;
}
```

### 4. Edge Bundling

Combine edges traveling similar paths to reduce visual clutter:

```typescript
// D3 edge bundling (requires additional library)
import { forceEdgeBundling } from 'd3-force-bundle';

const bundledEdges = forceEdgeBundling()
  .nodes(nodes)
  .edges(edges)
  .bundling_stiffness(0.5)
  .step_size(0.1)
  ();
```

**Note:** Edge bundling is complex to integrate with React Flow. Consider it for dense network graphs only.

## Common Problems and Solutions

### Problem: Edges Crossing Through Nodes

**Cause:** Layout doesn't account for edge routing, or using straight edges.

**Solutions:**

1. Use step/smoothstep edges:
```typescript
const edge = { type: 'smoothstep' };
```

2. Increase node spacing:
```typescript
dagreGraph.setGraph({
  nodesep: 100,  // More horizontal space
  ranksep: 150,  // More vertical space
});
```

3. Use ELK with orthogonal routing:
```typescript
{
  'elk.layered.edgeRouting': 'ORTHOGONAL',
  'elk.spacing.edgeNode': '30',
}
```

### Problem: Edges Overlapping Each Other

**Cause:** Multiple edges between same nodes, or parallel edges.

**Solutions:**

1. Use separate handles for each connection:
```typescript
// Instead of multiple edges to same handle
<Handle id="out-1" position={Position.Bottom} style={{ left: '30%' }} />
<Handle id="out-2" position={Position.Bottom} style={{ left: '70%' }} />
```

2. Offset parallel edges:
```typescript
function getParallelEdgeOffset(edges, currentEdge) {
  const parallelEdges = edges.filter(e =>
    (e.source === currentEdge.source && e.target === currentEdge.target) ||
    (e.source === currentEdge.target && e.target === currentEdge.source)
  );
  const index = parallelEdges.findIndex(e => e.id === currentEdge.id);
  return (index - (parallelEdges.length - 1) / 2) * 20;
}
```

3. Use ELK edge spacing:
```typescript
{
  'elk.spacing.edgeEdge': '20',
}
```

### Problem: Self-Loops Look Bad

**Cause:** Default rendering doesn't handle source === target.

**Solution:** Custom self-loop edge:

```typescript
function SelfLoopEdge({ sourceX, sourceY }) {
  const radiusX = 40;
  const radiusY = 30;

  const path = `M ${sourceX} ${sourceY}
    C ${sourceX + radiusX} ${sourceY - radiusY},
      ${sourceX + radiusX} ${sourceY + radiusY},
      ${sourceX} ${sourceY}`;

  return <path d={path} fill="none" stroke="#888" />;
}

// Register edge type
const edgeTypes = { selfLoop: SelfLoopEdge };
```

### Problem: Edges Don't Follow Handle Direction

**Cause:** Mismatched handle positions vs layout direction.

**Debug checklist:**
1. Check node's `sourcePosition` and `targetPosition`
2. Check custom node's `<Handle position={...}>` props
3. Verify layout direction matches handle setup
4. Check if edges specify `sourceHandle`/`targetHandle` that don't exist

```typescript
// Debug: log handle setup
console.log('Node positions:', nodes.map(n => ({
  id: n.id,
  source: n.sourcePosition,
  target: n.targetPosition,
})));
```

## Advanced Techniques

### Dynamic Handle Positioning

Adjust handles based on edge direction:

```typescript
function useSmartHandles(node, edges) {
  const incomingEdges = edges.filter(e => e.target === node.id);
  const outgoingEdges = edges.filter(e => e.source === node.id);

  // Distribute handles based on connections
  return {
    targetHandles: incomingEdges.map((e, i) => ({
      id: `target-${e.id}`,
      position: Position.Top,
      style: { left: `${(i + 1) * (100 / (incomingEdges.length + 1))}%` },
    })),
    sourceHandles: outgoingEdges.map((e, i) => ({
      id: `source-${e.id}`,
      position: Position.Bottom,
      style: { left: `${(i + 1) * (100 / (outgoingEdges.length + 1))}%` },
    })),
  };
}
```

### Avoiding Edge-Node Intersections (Manual)

When auto-routing fails, add waypoints:

```typescript
// Not natively supported in React Flow
// Workaround: Use invisible intermediate nodes

const waypointNode = {
  id: 'waypoint-1',
  position: { x: 150, y: 75 },
  type: 'waypoint',  // Custom invisible node type
  data: {},
};

// Split edge into two segments
const edges = [
  { id: 'e1a', source: 'node1', target: 'waypoint-1' },
  { id: 'e1b', source: 'waypoint-1', target: 'node2' },
];
```

### Port-Based Routing with ELK

For precise control over connection points:

```typescript
const elkGraph = {
  children: [{
    id: 'node1',
    width: 200,
    height: 100,
    ports: [
      { id: 'p1', width: 10, height: 10, properties: { 'port.side': 'SOUTH' } },
      { id: 'p2', width: 10, height: 10, properties: { 'port.side': 'EAST' } },
    ],
    properties: {
      'portConstraints': 'FIXED_SIDE',
    },
  }],
  edges: [{
    id: 'e1',
    sources: ['node1:p1'],  // Use port
    targets: ['node2:p3'],
  }],
};
```
