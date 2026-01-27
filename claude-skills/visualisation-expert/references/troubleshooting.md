# Troubleshooting Reference

Systematic debugging for graph visualisation problems.

## Quick Diagnosis Checklist

Run through this when your graph looks wrong:

```
□ 1. Is layout actually running?
     → Add console.log after layout call
     → Check for async timing issues

□ 2. Are node dimensions correct?
     → Log dimensions passed to layout engine
     → Compare to actual rendered size

□ 3. Do handle positions match layout direction?
     → TB layout needs sourcePosition: bottom, targetPosition: top

□ 4. Are you overwriting computed positions?
     → Check for position assignments after layout

□ 5. Is the data structure correct?
     → DAG vs tree vs cyclic - does your algorithm support it?
```

## Problem: Nodes Overlapping

### Symptom
Nodes render on top of each other, partially or completely.

### Causes & Solutions

**1. Node dimensions not passed to layout**

```typescript
// WRONG - uses default 0x0 or tiny dimensions
dagreGraph.setNode(node.id, {});

// RIGHT - pass actual dimensions
dagreGraph.setNode(node.id, {
  width: node.measured?.width ?? 172,
  height: node.measured?.height ?? 36,
});
```

**2. Layout doesn't know about custom node sizes**

```typescript
// If using variable-size nodes, measure them first
const NODE_DIMENSIONS = {
  default: { width: 172, height: 36 },
  large: { width: 250, height: 100 },
  decision: { width: 100, height: 100 },
};

nodes.forEach(node => {
  const dims = NODE_DIMENSIONS[node.type] ?? NODE_DIMENSIONS.default;
  dagreGraph.setNode(node.id, dims);
});
```

**3. Insufficient spacing**

```typescript
dagreGraph.setGraph({
  nodesep: 80,   // Increase horizontal gap
  ranksep: 120,  // Increase vertical gap
});

// ELK equivalent
{
  'elk.spacing.nodeNode': '80',
  'elk.layered.spacing.nodeNodeBetweenLayers': '120',
}
```

**4. Position coordinate mismatch**

```typescript
// Dagre returns CENTER coordinates
// React Flow expects TOP-LEFT coordinates
const position = {
  x: dagreNode.x - nodeWidth / 2,   // Convert to top-left
  y: dagreNode.y - nodeHeight / 2,
};
```

## Problem: Edges Crossing Through Nodes

### Symptom
Lines go straight through node bodies instead of around them.

### Causes & Solutions

**1. Using straight edges**

```typescript
// WRONG for most cases
const edge = { type: 'straight' };

// RIGHT - use step or smoothstep
const edge = { type: 'smoothstep' };
```

**2. Layout doesn't route edges around obstacles**

```typescript
// Dagre doesn't do obstacle avoidance
// Switch to ELK with orthogonal routing

{
  'elk.algorithm': 'layered',
  'elk.layered.edgeRouting': 'ORTHOGONAL',
  'elk.spacing.edgeNode': '30',  // Minimum edge-to-node distance
}
```

**3. Insufficient spacing for edge routing**

```typescript
// Edges need room to route around nodes
{
  nodesep: 100,  // More space = cleaner routing
  ranksep: 150,
}
```

## Problem: Wrong Hierarchy Direction

### Symptom
Children appear above parents, or hierarchy is sideways when it should be vertical.

### Causes & Solutions

**1. Wrong rankdir**

```typescript
// For top-to-bottom hierarchy
dagreGraph.setGraph({ rankdir: 'TB' });

// For left-to-right hierarchy
dagreGraph.setGraph({ rankdir: 'LR' });
```

**2. Edge direction reversed in data**

```typescript
// Check your edge definitions
// source should be PARENT, target should be CHILD
const edge = {
  source: parentNode.id,  // Where edge starts
  target: childNode.id,   // Where edge ends
};

// If your data has it backwards, flip it:
const correctedEdges = edges.map(e => ({
  ...e,
  source: e.target,
  target: e.source,
}));
```

**3. Handle positions don't match direction**

```typescript
// For TB layout:
node.sourcePosition = Position.Bottom;  // Outgoing edges from bottom
node.targetPosition = Position.Top;     // Incoming edges to top

// For LR layout:
node.sourcePosition = Position.Right;
node.targetPosition = Position.Left;
```

## Problem: Nodes in Random Positions

### Symptom
Nodes appear scattered without any logical arrangement.

### Causes & Solutions

**1. Layout not running at all**

```typescript
// Check that layout code actually executes
const { nodes: layoutedNodes } = getLayoutedElements(nodes, edges);
console.log('Layout complete:', layoutedNodes[0]?.position);

// Common issue: async layout with sync rendering
// ELK is async - must await
const layoutedGraph = await elk.layout(elkGraph);  // Don't forget await!
```

**2. Layout runs after render, positions overwritten**

```typescript
// WRONG - layout effect runs, then something overwrites
useEffect(() => {
  const layouted = doLayout(nodes, edges);
  setNodes(layouted);  // This is correct...
}, []);

// ...but then elsewhere:
onNodesChange={(changes) => setNodes(applyChanges(changes, nodes))};
// ^ This might reset positions if changes include position

// Debug: log whenever nodes change
useEffect(() => {
  console.log('Nodes updated:', nodes.map(n => n.position));
}, [nodes]);
```

**3. Nodes have position: {x: 0, y: 0} before layout**

```typescript
// If initialising nodes without positions:
const initialNodes = data.map(d => ({
  id: d.id,
  data: d,
  position: { x: 0, y: 0 },  // Temporary, will be replaced
}));

// Make sure layout runs before first meaningful render
// Use a loading state:
const [isLayouted, setIsLayouted] = useState(false);

if (!isLayouted) return <LoadingSpinner />;
```

**4. Empty edges array**

```typescript
// Layout algorithms use edges to determine relationships
// No edges = no structure = random placement

console.log('Edges:', edges);  // Should not be empty if you expect hierarchy
```

## Problem: Edges Don't Connect Properly

### Symptom
Edges connect to wrong points on nodes, or don't connect at all.

### Causes & Solutions

**1. Handle IDs don't match edge definitions**

```typescript
// In custom node:
<Handle type="source" id="output-1" position={Position.Bottom} />

// In edge - ID must match EXACTLY
const edge = {
  source: 'node1',
  sourceHandle: 'output-1',  // Must match Handle id
  target: 'node2',
  targetHandle: 'input-1',   // Must match target's Handle id
};
```

**2. Handles not rendered (conditional rendering bug)**

```typescript
// WRONG - handle disappears when condition is false
function CustomNode({ data }) {
  return (
    <div>
      {data.hasOutput && <Handle type="source" position={Position.Bottom} />}
    </div>
  );
}

// If data.hasOutput becomes false, edge has nowhere to connect
```

**3. Handle position hardcoded vs layout-driven**

```typescript
// Custom node with fixed handles:
<Handle position={Position.Bottom} />

// But layout set different positions on node:
node.sourcePosition = Position.Right;  // Conflict!

// Solution: Use node's positions in custom node:
function CustomNode({ sourcePosition, targetPosition }) {
  return (
    <>
      <Handle type="target" position={targetPosition} />
      <Handle type="source" position={sourcePosition} />
    </>
  );
}
```

## Problem: Performance Issues

### Symptom
Slow rendering, laggy interactions, browser freezing.

### Diagnosis

```typescript
// Profile what's slow:
console.time('layout');
const layouted = getLayoutedElements(nodes, edges);
console.timeEnd('layout');

console.time('render');
setNodes(layouted);
console.timeEnd('render');
```

### Solutions by Cause

**1. Re-layout on every render**

```typescript
// WRONG - infinite loop or constant re-computation
useEffect(() => {
  const layouted = doLayout(nodes, edges);
  setNodes(layouted);  // Triggers re-render, which triggers effect...
}, [nodes, edges]);

// RIGHT - layout only when data structure changes
const [needsLayout, setNeedsLayout] = useState(true);

useEffect(() => {
  if (needsLayout) {
    setNodes(doLayout(nodes, edges));
    setNeedsLayout(false);
  }
}, [needsLayout]);
```

**2. Too many nodes for algorithm**

| Algorithm | Comfortable Limit | Pushing It |
|-----------|-------------------|------------|
| Dagre | 500 | 1000 |
| ELK | 1000 | 2000 |
| D3-force | 300 | 500 |

Solutions for large graphs:
- Cluster and show/hide
- Virtual scrolling (show only visible nodes)
- Use WebGL renderer (react-force-graph, Sigma.js)
- Server-side layout

**3. Complex custom nodes**

```typescript
// WRONG - heavy computation in render
function HeavyNode({ data }) {
  const processed = expensiveOperation(data);  // Runs every render!
  return <div>{processed}</div>;
}

// RIGHT - memoize
const HeavyNode = memo(function HeavyNode({ data }) {
  const processed = useMemo(() => expensiveOperation(data), [data]);
  return <div>{processed}</div>;
});
```

**4. Force simulation never settles**

```typescript
// Force simulation keeps running, updating positions forever
// Configure to stop:
simulation
  .alphaDecay(0.02)     // Cool down faster
  .alphaMin(0.001)      // Stop when alpha < this
  .velocityDecay(0.4);  // More friction

// Or stop manually after N ticks:
simulation.tick(300);
simulation.stop();
```

## Problem: React Flow Specific Issues

### fitView doesn't work

```typescript
// fitView runs before layout completes
// WRONG:
<ReactFlow nodes={nodes} fitView />

// RIGHT - call after layout:
const { fitView } = useReactFlow();

useEffect(() => {
  const layouted = doLayout(nodes, edges);
  setNodes(layouted);
  // Wait for React to render, then fit:
  setTimeout(() => fitView({ padding: 0.2 }), 0);
}, [dataChanged]);
```

### Nodes jump on first interaction

```typescript
// Cause: Initial render has placeholder positions
// Layout runs, positions update, nodes "jump"

// Solution: Don't render until layout complete
const [ready, setReady] = useState(false);

useEffect(() => {
  const layouted = doLayout(nodes, edges);
  setNodes(layouted);
  setReady(true);
}, []);

if (!ready) return <Loading />;
return <ReactFlow ... />;
```

### Controlled vs uncontrolled warnings

```typescript
// WRONG - mixing controlled and uncontrolled
<ReactFlow
  defaultNodes={initialNodes}  // Uncontrolled
  nodes={nodes}                // Controlled - conflict!
  ...
/>

// RIGHT - pick one:
// Controlled (recommended for dynamic graphs):
<ReactFlow nodes={nodes} onNodesChange={onNodesChange} />

// Uncontrolled (for static graphs):
<ReactFlow defaultNodes={initialNodes} />
```

## Debug Logging Template

Add this to diagnose layout issues:

```typescript
function debugLayout(nodes, edges, phase) {
  console.group(`Layout Debug: ${phase}`);
  console.log('Node count:', nodes.length);
  console.log('Edge count:', edges.length);
  console.log('Sample node:', {
    id: nodes[0]?.id,
    position: nodes[0]?.position,
    width: nodes[0]?.width,
    height: nodes[0]?.height,
    sourcePosition: nodes[0]?.sourcePosition,
    targetPosition: nodes[0]?.targetPosition,
  });
  console.log('Sample edge:', {
    id: edges[0]?.id,
    source: edges[0]?.source,
    target: edges[0]?.target,
    sourceHandle: edges[0]?.sourceHandle,
    targetHandle: edges[0]?.targetHandle,
  });
  console.groupEnd();
}

// Usage:
debugLayout(nodes, edges, 'before layout');
const layouted = doLayout(nodes, edges);
debugLayout(layouted.nodes, layouted.edges, 'after layout');
```
