# React Flow Reference

React Flow is the primary library for this skill. It provides a React-based canvas for node-edge diagrams with built-in pan/zoom, selection, and extensibility.

## Core Concepts

### Nodes and Edges

```typescript
// Node structure
interface Node {
  id: string;
  type?: string;           // Custom node type
  position: { x: number; y: number };
  data: Record<string, any>;
  width?: number;          // Important for layout!
  height?: number;         // Important for layout!
  sourcePosition?: Position;
  targetPosition?: Position;
}

// Edge structure
interface Edge {
  id: string;
  source: string;          // Source node ID
  target: string;          // Target node ID
  sourceHandle?: string;   // Specific handle on source
  targetHandle?: string;   // Specific handle on target
  type?: string;           // 'default' | 'straight' | 'step' | 'smoothstep' | 'bezier'
  animated?: boolean;
  label?: string;
}
```

### Handle Positions

Handles are connection points on nodes. Position matters for layout:

```typescript
type Position = 'top' | 'right' | 'bottom' | 'left';

// For top-to-bottom layouts (TB):
// - Source handles should be on 'bottom'
// - Target handles should be on 'top'

// For left-to-right layouts (LR):
// - Source handles should be on 'right'
// - Target handles should be on 'left'
```

**Common mistake:** Mismatched handle positions cause edges to route incorrectly or create visual chaos.

## Layout Integration

React Flow does NOT include automatic layout. You must integrate an external layout engine.

### Dagre Integration (Most Common)

```typescript
import dagre from 'dagre';
import { Node, Edge } from 'reactflow';

const dagreGraph = new dagre.graphlib.Graph();
dagreGraph.setDefaultEdgeLabel(() => ({}));

export function getLayoutedElements(
  nodes: Node[],
  edges: Edge[],
  direction: 'TB' | 'LR' | 'BT' | 'RL' = 'TB'
) {
  const isHorizontal = direction === 'LR' || direction === 'RL';

  dagreGraph.setGraph({
    rankdir: direction,
    nodesep: 50,      // Horizontal spacing between nodes
    ranksep: 100,     // Vertical spacing between ranks
    edgesep: 10,      // Minimum edge separation
    marginx: 20,
    marginy: 20,
  });

  // CRITICAL: Pass actual node dimensions
  nodes.forEach((node) => {
    dagreGraph.setNode(node.id, {
      width: node.width ?? 172,   // Default React Flow node width
      height: node.height ?? 36,  // Default React Flow node height
    });
  });

  edges.forEach((edge) => {
    dagreGraph.setEdge(edge.source, edge.target);
  });

  dagre.layout(dagreGraph);

  const layoutedNodes = nodes.map((node) => {
    const nodeWithPosition = dagreGraph.node(node.id);
    return {
      ...node,
      // Dagre returns center position; React Flow uses top-left
      position: {
        x: nodeWithPosition.x - (node.width ?? 172) / 2,
        y: nodeWithPosition.y - (node.height ?? 36) / 2,
      },
      // Set handle positions based on direction
      targetPosition: isHorizontal ? 'left' : 'top',
      sourcePosition: isHorizontal ? 'right' : 'bottom',
    };
  });

  return { nodes: layoutedNodes, edges };
}
```

### ELK Integration (More Powerful)

ELK (Eclipse Layout Kernel) offers more sophisticated algorithms:

```typescript
import ELK from 'elkjs/lib/elk.bundled.js';

const elk = new ELK();

export async function getElkLayout(
  nodes: Node[],
  edges: Edge[],
  options: Record<string, string> = {}
) {
  const elkGraph = {
    id: 'root',
    layoutOptions: {
      'elk.algorithm': 'layered',
      'elk.direction': 'DOWN',
      'elk.spacing.nodeNode': '50',
      'elk.layered.spacing.nodeNodeBetweenLayers': '100',
      ...options,
    },
    children: nodes.map((node) => ({
      id: node.id,
      width: node.width ?? 172,
      height: node.height ?? 36,
    })),
    edges: edges.map((edge) => ({
      id: edge.id,
      sources: [edge.source],
      targets: [edge.target],
    })),
  };

  const layoutedGraph = await elk.layout(elkGraph);

  const layoutedNodes = nodes.map((node) => {
    const elkNode = layoutedGraph.children?.find((n) => n.id === node.id);
    return {
      ...node,
      position: { x: elkNode?.x ?? 0, y: elkNode?.y ?? 0 },
    };
  });

  return { nodes: layoutedNodes, edges };
}
```

## Common Patterns

### Auto-Layout on Data Change

```typescript
function Flow() {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);

  // Re-layout when data changes
  useEffect(() => {
    const { nodes: layoutedNodes, edges: layoutedEdges } = getLayoutedElements(
      nodes,
      edges,
      'TB'
    );
    setNodes(layoutedNodes);
    setEdges(layoutedEdges);
  }, [/* dependencies that trigger re-layout */]);

  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      onNodesChange={onNodesChange}
      onEdgesChange={onEdgesChange}
      fitView
    />
  );
}
```

**Warning:** Don't include `nodes` or `edges` in the useEffect dependencies if you're setting them in the same effect—infinite loop!

### Measuring Node Dimensions

React Flow doesn't know node dimensions until render. For accurate layout:

```typescript
// Option 1: Fixed dimensions (simplest)
const NODE_WIDTH = 200;
const NODE_HEIGHT = 50;

// Option 2: Measure after render
function useNodeDimensions(nodeId: string) {
  const nodeRef = useRef<HTMLDivElement>(null);
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 });

  useEffect(() => {
    if (nodeRef.current) {
      const { width, height } = nodeRef.current.getBoundingClientRect();
      setDimensions({ width, height });
    }
  }, []);

  return { ref: nodeRef, ...dimensions };
}

// Option 3: Use React Flow's internal measurements
// Access via useNodes() after initial render
```

### Combining Auto-Layout with Manual Adjustments

```typescript
const [isLayouted, setIsLayouted] = useState(false);

// Initial auto-layout
useEffect(() => {
  if (!isLayouted && nodes.length > 0) {
    const { nodes: layouted } = getLayoutedElements(nodes, edges, 'TB');
    setNodes(layouted);
    setIsLayouted(true);
  }
}, [nodes.length]);

// Allow manual dragging after initial layout
// onNodesChange handles drag updates automatically
```

## Performance

### Node Count Guidelines

| Node Count | Recommendation |
|------------|----------------|
| < 100 | Standard React Flow, any layout |
| 100-500 | Consider `nodesDraggable={false}` during layout |
| 500-2000 | Use `onlyRenderVisibleElements`, simplify node components |
| > 2000 | Consider WebGL alternatives (react-force-graph, Sigma.js) |

### Optimisation Techniques

```typescript
// 1. Memoize custom nodes
const CustomNode = memo(({ data }) => {
  return <div>{data.label}</div>;
});

// 2. Disable features during layout
<ReactFlow
  nodesDraggable={!isLayouting}
  nodesConnectable={!isLayouting}
  elementsSelectable={!isLayouting}
/>

// 3. Batch updates
setNodes((nds) => nds.map((node) => ({
  ...node,
  position: newPositions[node.id],
})));

// 4. Use nodeTypes object reference stability
const nodeTypes = useMemo(() => ({
  custom: CustomNode,
}), []);
```

## Gotchas

1. **Position is top-left, not center** — Layout engines often return center coordinates

2. **Edges need unique IDs** — Duplicate IDs cause rendering bugs

3. **Handle IDs must match** — `sourceHandle` and `targetHandle` must exactly match handle `id` props

4. **fitView timing** — Call `fitView()` after layout completes, not before

5. **SSR issues** — React Flow requires browser APIs; use dynamic import with `ssr: false` in Next.js

6. **Controlled vs uncontrolled** — Mixing `defaultNodes` with `nodes` prop causes bugs

7. **Edge type changes** — Changing edge `type` requires edge `id` change or React won't re-render
