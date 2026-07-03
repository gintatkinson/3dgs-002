/**
 * @realizes UML::TopologyMap
 * Properties:
 * - activeFocusedNode: String
 * - onNodeSelect: Function
 * - updateCoordinateMapping: Function
 *
 * @realizes UML::PlaybackController
 * Properties:
 * - currentTimeIndex: Real
 * - playbackSpeedMultiplier: Real
 * - isPlaying: Boolean
 * - setPlayhead: Function
 * - togglePlayback: Function
 *
 * @realizes UML::CanvasRenderer
 * Properties:
 * - renderContextType: String
 * - drawViewport: Function
 */

import React, { useEffect, useRef, useState } from 'react';

export interface TopologyNode {
  id: string;
  label: string;
  position: {
    dim_0: number;
    dim_1: number;
    dim_2: number;
    time_index: number;
    vector: number[];
  };
  status: string;
}

export interface TopologyLink {
  source: string;
  target: string;
  type: string;
}

export interface TopologyData {
  coordinateMapping: Record<string, string>;
  nodes: TopologyNode[];
  links: TopologyLink[];
}

export interface TopologyMapProps {
  activeFocusedNode?: string | null;
  onNodeSelect?: (nodeId: string) => void;
  data?: TopologyData;
}

/**
 * TopologyMap Component
 *
 * @param props - The properties for the TopologyMap component.
 * @returns The rendered topology canvas and playback controls.
 */
export const TopologyMap: React.FC<TopologyMapProps> = ({
  activeFocusedNode = null,
  onNodeSelect,
  data,
}) => {
  // --- 1. UML::TopologyMap State & Mappings ---
  const [coordinateMapping, setCoordinateMapping] = useState<string>(
    JSON.stringify(
      data?.coordinateMapping || {
        x: 'position/dim_0',
        y: 'position/dim_1',
        z: 'position/dim_2',
        t: 'position/time_index',
        trajectory: 'position/vector',
      }
    )
  );

  const updateCoordinateMapping = (mapping: string) => {
    setCoordinateMapping(mapping);
  };

  // Default mock data if none is provided
  const defaultData: TopologyData = {
    coordinateMapping: {
      x: 'position/dim_0',
      y: 'position/dim_1',
      z: 'position/dim_2',
      t: 'position/time_index',
      trajectory: 'position/vector',
    },
    nodes: [
      {
        id: 'Ingestion',
        label: 'Ingestion',
        position: {
          dim_0: 100,
          dim_1: 140,
          dim_2: 0.0,
          time_index: 1.0,
          vector: [15, 3, 0.0],
        },
        status: 'Active',
      },
      {
        id: 'Metrics',
        label: 'Metrics',
        position: {
          dim_0: 320,
          dim_1: 90,
          dim_2: 0.0,
          time_index: 1.0,
          vector: [8, -4, 0.0],
        },
        status: 'Active',
      },
      {
        id: 'Location',
        label: 'Location',
        position: {
          dim_0: 240,
          dim_1: 220,
          dim_2: 0.0,
          time_index: 1.0,
          vector: [4, 10, 0.0],
        },
        status: 'Active',
      },
      {
        id: 'Chassis',
        label: 'Chassis',
        position: {
          dim_0: 480,
          dim_1: 180,
          dim_2: 0.0,
          time_index: 1.0,
          vector: [-6, 6, 0.0],
        },
        status: 'Idle',
      },
    ],
    links: [
      { source: 'Ingestion', target: 'Metrics', type: 'data-flow' },
      { source: 'Metrics', target: 'Chassis', type: 'data-flow' },
      { source: 'Location', target: 'Chassis', type: 'data-flow' },
    ],
  };

  const activeData = data || defaultData;

  // --- 2. UML::PlaybackController State & Controls ---
  const [currentTimeIndex, setCurrentTimeIndex] = useState<number>(1.0);
  const [playbackSpeedMultiplier, setPlaybackSpeedMultiplier] = useState<number>(1.0);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);

  const setPlayhead = (timeIndex: number) => {
    setCurrentTimeIndex(Math.max(1.0, Math.min(timeIndex, 10.0)));
  };

  const togglePlayback = () => {
    setIsPlaying((prev: boolean) => !prev);
  };

  // Playback tick timer using requestAnimationFrame
  useEffect(() => {
    let animationFrameId: number;
    let lastTime = performance.now();

    const tick = () => {
      const now = performance.now();
      const deltaSeconds = (now - lastTime) / 1000;
      lastTime = now;

      if (isPlaying) {
        setCurrentTimeIndex((prev: number) => {
          let next = prev + deltaSeconds * playbackSpeedMultiplier;
          if (next > 10.0) {
            next = 1.0; // Loop back
          }
          return next;
        });
      }
      animationFrameId = requestAnimationFrame(tick);
    };

    animationFrameId = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(animationFrameId);
    };
  }, [isPlaying, playbackSpeedMultiplier]);

  // --- 3. UML::CanvasRenderer ---
  const renderContextType = '2d';
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  const drawViewport = (ctx: CanvasRenderingContext2D) => {
    const width = ctx.canvas.width;
    const height = ctx.canvas.height;

    // Clear viewport with dark theme colors
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, width, height);

    // Draw grid lines
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 1;
    for (let x = 0; x < width; x += 40) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    }
    for (let y = 0; y < height; y += 40) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    // Compute nodes projected positions at currentTimeIndex
    const projectedNodes = activeData.nodes.map((node: TopologyNode) => {
      const dt = currentTimeIndex - node.position.time_index;
      const vx = node.position.vector[0] || 0;
      const vy = node.position.vector[1] || 0;

      // Projected coords based on base position + dt * vector velocity
      const x = node.position.dim_0 + dt * vx;
      const y = node.position.dim_1 + dt * vy;

      return {
        ...node,
        x,
        y,
      };
    });

    // Draw links/trajectories
    activeData.links.forEach((link: TopologyLink) => {
      const sourceNode = projectedNodes.find((n: any) => n.id === link.source);
      const targetNode = projectedNodes.find((n: any) => n.id === link.target);

      if (sourceNode && targetNode) {
        // Draw connector link line
        ctx.beginPath();
        ctx.moveTo(sourceNode.x, sourceNode.y);
        ctx.lineTo(targetNode.x, targetNode.y);

        ctx.strokeStyle = 'rgba(59, 130, 246, 0.35)';
        ctx.lineWidth = 2;
        ctx.stroke();

        // Animated data packet along link path
        const packetRatio = (currentTimeIndex % 2.0) / 2.0;
        const px = sourceNode.x + (targetNode.x - sourceNode.x) * packetRatio;
        const py = sourceNode.y + (targetNode.y - sourceNode.y) * packetRatio;
        ctx.beginPath();
        ctx.arc(px, py, 4, 0, 2 * Math.PI);
        ctx.fillStyle = '#60a5fa';
        ctx.fill();
      }
    });

    // Draw nodes
    projectedNodes.forEach((node: any) => {
      const isFocused = activeFocusedNode === node.id;

      // Draw vector trajectory path
      const vx = node.position.vector[0] || 0;
      const vy = node.position.vector[1] || 0;
      ctx.beginPath();
      ctx.moveTo(node.x, node.y);
      ctx.lineTo(node.x + vx * 2, node.y + vy * 2);
      ctx.strokeStyle = 'rgba(239, 68, 68, 0.4)';
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Node base circle representation
      ctx.beginPath();
      ctx.arc(node.x, node.y, isFocused ? 12 : 9, 0, 2 * Math.PI);

      if (isFocused) {
        ctx.fillStyle = '#3b82f6';
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 2.5;
      } else {
        ctx.fillStyle = node.status === 'Active' ? '#10b981' : '#f59e0b';
        ctx.strokeStyle = '#1e293b';
        ctx.lineWidth = 2;
      }

      ctx.fill();
      ctx.stroke();

      // Pulsing glow halo for selected/focused node
      if (isFocused) {
        ctx.beginPath();
        ctx.arc(node.x, node.y, 20, 0, 2 * Math.PI);
        ctx.strokeStyle = 'rgba(59, 130, 246, 0.3)';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }

      // Draw label
      ctx.fillStyle = '#f8fafc';
      ctx.font = '12px Outfit, Inter, system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(node.label, node.x, node.y + 14);
    });
  };

  // Click handler to select node on canvas click
  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    e.stopPropagation();
    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;

    const clickedNode = activeData.nodes.find((node: TopologyNode) => {
      const dt = currentTimeIndex - node.position.time_index;
      const vx = node.position.vector[0] || 0;
      const vy = node.position.vector[1] || 0;
      const nodeX = node.position.dim_0 + dt * vx;
      const nodeY = node.position.dim_1 + dt * vy;

      const dist = Math.hypot(clickX - nodeX, clickY - nodeY);
      return dist <= 20; // 20px proximity
    });

    if (clickedNode && onNodeSelect) {
      onNodeSelect(clickedNode.id);
    }
  };

  // Resize canvas handler
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resizeObserver = new ResizeObserver((entries: any[]) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        canvas.width = width || 800;
        canvas.height = height || 280;

        const ctx = canvas.getContext(renderContextType);
        if (ctx) {
          drawViewport(ctx);
        }
      }
    });

    if (canvas) {
      resizeObserver.observe(canvas);
    }

    return () => {
      resizeObserver.disconnect();
    };
  }, [currentTimeIndex, activeFocusedNode, activeData]);

  // Redraw when state updates
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext(renderContextType);
    if (!ctx) return;

    drawViewport(ctx);
  }, [currentTimeIndex, activeFocusedNode, activeData]);

  return (
    <div
      className="topology-container"
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        backgroundColor: '#0f172a',
        position: 'relative',
        fontFamily: 'Outfit, Inter, system-ui',
      }}
    >
      {/* Canvas Viewport container */}
      <div style={{ flex: 1, position: 'relative', overflow: 'auto' }}>
        <canvas
          ref={canvasRef}
          onClick={handleCanvasClick}
          style={{
            display: 'block',
            width: '100%',
            height: '100%',
            minWidth: '800px',
            minHeight: '500px',
            cursor: 'pointer',
          }}
        />
      </div>

      {/* Playback scrubber timeline controller */}
      <div
        className="playback-controller-panel"
        style={{
          padding: '12px 16px',
          borderTop: '1px solid #1e293b',
          backgroundColor: '#0f172a',
          display: 'flex',
          alignItems: 'center',
          gap: '16px',
          zIndex: 10,
        }}
      >
        <button
          onClick={togglePlayback}
          style={{
            backgroundColor: isPlaying ? '#ef4444' : '#3b82f6',
            color: '#fff',
            border: 'none',
            borderRadius: '4px',
            padding: '6px 12px',
            cursor: 'pointer',
            fontWeight: '600',
            fontSize: '13px',
            minWidth: '70px',
            transition: 'background-color 0.2s',
          }}
        >
          {isPlaying ? 'Pause' : 'Play'}
        </button>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            color: '#94a3b8',
            fontSize: '13px',
          }}
        >
          <span>t:</span>
          <span style={{ fontFamily: 'monospace', fontWeight: 'bold', width: '32px' }}>
            {currentTimeIndex.toFixed(1)}
          </span>
        </div>

        <input
          type="range"
          min="1.0"
          max="10.0"
          step="0.1"
          value={currentTimeIndex}
          onChange={(e) => setPlayhead(parseFloat(e.target.value))}
          style={{
            flex: 1,
            cursor: 'pointer',
            height: '6px',
            borderRadius: '3px',
            accentColor: '#3b82f6',
          }}
        />

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ color: '#94a3b8', fontSize: '12px' }}>Speed:</span>
          <select
            value={playbackSpeedMultiplier}
            onChange={(e) => setPlaybackSpeedMultiplier(parseFloat(e.target.value))}
            style={{
              backgroundColor: '#1e293b',
              color: '#f8fafc',
              border: '1px solid #334155',
              borderRadius: '4px',
              padding: '4px 8px',
              fontSize: '12px',
              cursor: 'pointer',
            }}
          >
            <option value="0.5">0.5x</option>
            <option value="1.0">1.0x</option>
            <option value="2.0">2.0x</option>
            <option value="5.0">5.0x</option>
          </select>
        </div>
      </div>
    </div>
  );
};
