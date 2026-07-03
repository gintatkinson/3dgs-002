/**
 * @realizes UML::Layout
 * Properties:
 * - activeView: String
 * - splitterHeight: Integer
 * - onViewChange: Function
 *
 * @realizes UML::HierarchyTreeSelector
 * Properties:
 * - onNodeSelect: Function
 * - handleKeyboardNavigation: Function
 *
 * @realizes UML::ResizableSplitter
 * Properties:
 * - axis: String
 * - defaultRatio: Real
 * - minSizePixels: Integer
 *
 * @realizes UML::TabbedContainer
 * Properties:
 * - activeTab: String
 *
 * @realizes UML::TableView
 * Properties:
 * - tableId: String
 */

import React, { useState, useRef, useEffect } from 'react';
import logicalLayout from '../../../.pipeline/logical-ui/logical-layout.json';
import { NavigationBreadcrumbs, BreadcrumbItem } from './breadcrumbs';
import { TopologyMap } from './topology-map';
import './layout.css';

export interface LayoutProps {
  activeView?: string;
  ActiveView?: string;
  onViewChange?: (view: string) => void;
  children?: React.ReactNode;
}

interface TreeNode {
  id: string;
  label: string;
  children?: TreeNode[];
}

const getNodeIconPath = (node: TreeNode, isParent: boolean): string => {
  if (isParent) {
    return 'M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z';
  }
  switch (node.id) {
    case 'Ingestion':
      return 'M8 5v14l11-7z';
    case 'Metrics':
      return 'M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0-2 .9-2-2V5c0-1.1-.9-2-2-2zm-2 10H7v-2h10v2zm0 4H7v-2h10v2zm0-8H7V7h10v2z';
    case 'Location':
      return 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z';
    case 'Chassis':
      return 'M2 20h20v-4H2v4zm2-3h2v2H4v-2zM2 4v4h20V4H2zm4 3H4V5h2v2zm-4 7h20v-4H2v4zm2-3h2v2H4v-2z';
    case 'Epics':
      return 'M12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-12c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z';
    case 'Traceability':
      return 'M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z';
    default:
      return '';
  }
};

const treeData: TreeNode[] = [
  { id: 'Ingestion', label: 'Ingestion' },
  {
    id: 'Monitoring',
    label: 'Monitoring',
    children: [
      { id: 'Metrics', label: 'Metrics' },
      { id: 'Location', label: 'Location' },
      { id: 'Chassis', label: 'Chassis' },
    ],
  },
  {
    id: 'Spec',
    label: 'Spec',
    children: [
      { id: 'Epics', label: 'Epics' },
      { id: 'Traceability', label: 'Traceability' },
    ],
  },
];

const getVisibleNodes = (nodes: TreeNode[], expanded: Record<string, boolean>): TreeNode[] => {
  const result: TreeNode[] = [];
  const traverse = (node: TreeNode) => {
    result.push(node);
    if (node.children && expanded[node.id]) {
      node.children.forEach(traverse);
    }
  };
  nodes.forEach(traverse);
  return result;
};

/**
 * Dynamic Layout Component (UML::Layout Realization)
 *
 * @param props - The layout properties.
 * @returns Dynamic parsed React layout structure.
 */
export const Layout: React.FC<LayoutProps> = ({
  activeView,
  ActiveView,
  onViewChange,
  children,
}) => {
  const currentView = activeView || ActiveView || 'Ingestion';
  const containerRef = useRef<HTMLDivElement>(null);
  const [splitterHeight, setSplitterHeight] = useState<number>(350);
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [sidebarWidth, setSidebarWidth] = useState<number>(240);
  const [isSidebarDragging, setIsSidebarDragging] = useState<boolean>(false);
  const [workerResult, setWorkerResult] = useState<number | null>(null);
  const workerRef = useRef<Worker | null>(null);
  const [topoMapHeight, setTopoMapHeight] = useState<number>(200);
  const [isTopoDragging, setIsTopoDragging] = useState<boolean>(false);
  const topoContainerRef = useRef<HTMLDivElement>(null);

  const [expanded, setExpanded] = useState<Record<string, boolean>>({
    Monitoring: true,
    Spec: true,
  });

  // TabbedContainer state (switching tables)
  const [activeTabId, setActiveTabId] = useState<string>('sub_elements_table');

  const [theme, setTheme] = useState<string>(() => localStorage.getItem('theme') || 'system');

  useEffect(() => {
    const updateTheme = () => {
      const isDark = theme === 'dark' || (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
      document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
    };

    updateTheme();
    localStorage.setItem('theme', theme);

    if (theme === 'system') {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const listener = (e: MediaQueryListEvent) => {
        const isDark = e.matches;
        document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
      };
      if (mediaQuery.addEventListener) {
        mediaQuery.addEventListener('change', listener);
      } else {
        mediaQuery.addListener(listener);
      }
      return () => {
        if (mediaQuery.removeEventListener) {
          mediaQuery.removeEventListener('change', listener);
        } else {
          mediaQuery.removeListener(listener);
        }
      };
    }
  }, [theme]);

  // Expand parent hierarchy programmatically when activeView / currentView changes
  useEffect(() => {
    if (currentView) {
      const newExpanded = { ...expanded };
      let changed = false;
      const findAndExpandParents = (
        nodes: TreeNode[],
        targetId: string,
        path: string[]
      ): boolean => {
        for (const node of nodes) {
          if (node.id === targetId) {
            path.forEach((id) => {
              if (!newExpanded[id]) {
                newExpanded[id] = true;
                changed = true;
              }
            });
            return true;
          }
          if (node.children) {
            if (findAndExpandParents(node.children, targetId, [...path, node.id])) {
              return true;
            }
          }
        }
        return false;
      };
      findAndExpandParents(treeData, currentView, []);
      if (changed) {
        setExpanded(newExpanded);
      }
    }
  }, [currentView]);

  // Initialize Web Worker for off-thread calculations (Platform Profile rule constraint)
  useEffect(() => {
    const code = `
      self.onmessage = function(e) {
        const val = e.data;
        let sum = 0;
        for (let i = 0; i < 1000000; i++) {
          sum += Math.sin(val + i);
        }
        self.postMessage(Math.round(sum));
      };
    `;
    const blob = new Blob([code], { type: 'application/javascript' });
    const worker = new Worker(URL.createObjectURL(blob));
    worker.onmessage = (e) => {
      setWorkerResult(e.data);
    };
    workerRef.current = worker;

    return () => {
      worker.terminate();
    };
  }, []);

  const triggerWorker = (inputVal: number) => {
    if (workerRef.current) {
      workerRef.current.postMessage(inputVal);
    }
  };

  const handlePointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsDragging(true);
    if (containerRef.current) {
      containerRef.current.classList.add('dragging');
    }
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging || !containerRef.current) return;
    e.stopPropagation();
    const rect = containerRef.current.getBoundingClientRect();
    const relativeY = e.clientY - rect.top;

    // Boundary checks: Keep within 150px and container height - 150px
    const newHeight = Math.max(150, Math.min(relativeY, rect.height - 150));
    setSplitterHeight(newHeight);

    triggerWorker(newHeight);
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsDragging(false);
    if (containerRef.current) {
      containerRef.current.classList.remove('dragging');
    }
    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
  };

  const handleSidebarPointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsSidebarDragging(true);
    if (containerRef.current) {
      containerRef.current.classList.add('dragging-sidebar');
    }
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handleSidebarPointerMove = (e: React.PointerEvent) => {
    if (!isSidebarDragging || !containerRef.current) return;
    e.stopPropagation();
    const rect = containerRef.current.getBoundingClientRect();
    const relativeX = e.clientX - rect.left;

    // Boundary checks: Keep within 150px and container width - 300px
    const newWidth = Math.max(150, Math.min(relativeX, rect.width - 300));
    setSidebarWidth(newWidth);
  };

  const handleSidebarPointerUp = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsSidebarDragging(false);
    if (containerRef.current) {
      containerRef.current.classList.remove('dragging-sidebar');
    }
    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
  };

  const handleTopoPointerDown = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsTopoDragging(true);
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handleTopoPointerMove = (e: React.PointerEvent) => {
    if (!isTopoDragging || !topoContainerRef.current) return;
    e.stopPropagation();
    const rect = topoContainerRef.current.getBoundingClientRect();
    const relativeY = e.clientY - rect.top;

    // Boundary checks: Keep within 100px and container height - 100px
    const newHeight = Math.max(100, Math.min(relativeY, rect.height - 100));
    setTopoMapHeight(newHeight);
  };

  const handleTopoPointerUp = (e: React.PointerEvent) => {
    e.stopPropagation();
    setIsTopoDragging(false);
    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
  };

  // Keyboard navigation handler (HierarchyTreeSelector realizing properties)
  const handleKeyDown = (e: React.KeyboardEvent) => {
    const visible = getVisibleNodes(treeData, expanded);
    const currentIndex = visible.findIndex((n) => n.id === currentView);

    switch (e.key) {
      case 'ArrowDown': {
        e.preventDefault();
        const nextIndex = currentIndex + 1;
        if (nextIndex < visible.length) {
          if (onViewChange) onViewChange(visible[nextIndex].id);
        }
        break;
      }
      case 'ArrowUp': {
        e.preventDefault();
        const prevIndex = currentIndex - 1;
        if (prevIndex >= 0) {
          if (onViewChange) onViewChange(visible[prevIndex].id);
        }
        break;
      }
      case 'ArrowRight': {
        e.preventDefault();
        const currentNode = visible[currentIndex];
        if (currentNode && currentNode.children && currentNode.children.length > 0) {
          if (!expanded[currentNode.id]) {
            setExpanded((prev) => ({ ...prev, [currentNode.id]: true }));
          } else {
            const firstChild = currentNode.children[0];
            if (onViewChange) onViewChange(firstChild.id);
          }
        }
        break;
      }
      case 'ArrowLeft': {
        e.preventDefault();
        const currentNode = visible[currentIndex];
        if (currentNode) {
          if (currentNode.children && currentNode.children.length > 0 && expanded[currentNode.id]) {
            setExpanded((prev) => ({ ...prev, [currentNode.id]: false }));
          } else {
            const findParent = (
              nodes: TreeNode[],
              targetId: string,
              parent: TreeNode | null
            ): TreeNode | null => {
              for (const node of nodes) {
                if (node.id === targetId) return parent;
                if (node.children) {
                  const found = findParent(node.children, targetId, node);
                  if (found) return found;
                }
              }
              return null;
            };
            const parent = findParent(treeData, currentNode.id, null);
            if (parent && onViewChange) {
              onViewChange(parent.id);
            }
          }
        }
        break;
      }
      default:
        break;
    }
  };

  const renderNode = (node: TreeNode) => {
    const isSelected = currentView === node.id;
    const isParent = !!(node.children && node.children.length > 0);
    const isExpanded = expanded[node.id];
    const iconPath = getNodeIconPath(node, isParent);

    return (
      <li
        key={node.id}
        className={`tree-node ${isParent ? 'parent' : 'leaf'} ${isSelected ? 'active' : ''}`}
        role="treeitem"
        aria-expanded={isParent ? isExpanded : undefined}
        aria-selected={isSelected}
      >
        <div
          className="tree-node-content"
          onClick={(e) => {
            e.stopPropagation();
            if (onViewChange) {
              onViewChange(node.id);
            }
          }}
        >
          {isParent ? (
            <button
              className="tree-toggle"
              aria-label={isExpanded ? 'Collapse' : 'Expand'}
              onClick={(e) => {
                e.stopPropagation();
                setExpanded((prev) => ({ ...prev, [node.id]: !prev[node.id] }));
              }}
            >
              {isExpanded ? '−' : '+'}
            </button>
          ) : (
            <span style={{ width: '16px', display: 'inline-block' }} />
          )}
          {iconPath && (
            <svg className="tree-node-icon" viewBox="0 0 24 24">
              <path d={iconPath} />
            </svg>
          )}
          <span className="tree-node-label">{node.label}</span>
        </div>
        {isParent && isExpanded && (
          <ul className="tree-child-list" role="group">
            {node.children!.map(renderNode)}
          </ul>
        )}
      </li>
    );
  };

  // Get Breadcrumbs path items dynamically based on selection
  const getBreadcrumbsItems = (view: string): BreadcrumbItem[] => {
    const base: BreadcrumbItem[] = [
      {
        id: 'home',
        label: 'Antigravity Console',
        onClick: () => onViewChange?.('Ingestion'),
      },
    ];

    if (view === 'Ingestion') {
      return [...base, { id: 'Ingestion', label: 'Ingestion' }];
    }
    if (['Metrics', 'Location', 'Chassis'].includes(view)) {
      return [
        ...base,
        {
          id: 'Monitoring',
          label: 'Monitoring',
          onClick: () => onViewChange?.('Metrics'),
        },
        { id: view, label: view },
      ];
    }
    if (['Epics', 'Traceability'].includes(view)) {
      return [
        ...base,
        {
          id: 'Spec',
          label: 'Spec',
          onClick: () => onViewChange?.('Epics'),
        },
        { id: view, label: view },
      ];
    }
    return [...base, { id: view, label: view }];
  };

  // Dynamic Table Data rendering (TableView properties)
  const renderTableContent = (tableId: string) => {
    const items = [
      { id: 'ITEM-001', name: 'Ingestion Pipeline', type: 'Worker', status: 'Active' },
      { id: 'ITEM-002', name: 'Telemetry DB', type: 'Database', status: 'Idle' },
      { id: 'ITEM-003', name: 'Web Console', type: 'Frontend', status: 'Active' },
    ];

    const statusAlarms = [
      {
        alarmId: 'ALARM-101',
        target: 'Telemetry DB',
        severity: 'Critical',
        timestamp: '2026-06-23 14:19',
      },
      {
        alarmId: 'ALARM-102',
        target: 'Ingestion Pipeline',
        severity: 'Warning',
        timestamp: '2026-06-23 14:20',
      },
    ];

    const activityEvents = [
      {
        eventId: 'EVENT-201',
        source: 'System',
        message: 'Console initialized',
        timestamp: '2026-06-23 14:19',
      },
      {
        eventId: 'EVENT-202',
        source: 'Worker',
        message: 'Registered off-thread background worker',
        timestamp: '2026-06-23 14:19',
      },
      {
        eventId: 'EVENT-203',
        source: 'UI',
        message: 'Selected panel reflow isolation scope active',
        timestamp: '2026-06-23 14:19',
      },
    ];

    if (tableId === 'sub_elements_table') {
      return (
        <table className="hd-table" data-testid="items-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>Type</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>{item.id}</td>
                <td>{item.name}</td>
                <td>{item.type}</td>
                <td>{item.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      );
    }

    if (tableId === 'active_alarms_table') {
      return (
        <table className="hd-table" data-testid="status-table">
          <thead>
            <tr>
              <th>Alarm ID</th>
              <th>Target</th>
              <th>Severity</th>
              <th>Timestamp</th>
            </tr>
          </thead>
          <tbody>
            {statusAlarms.map((alarm) => (
              <tr key={alarm.alarmId}>
                <td>{alarm.alarmId}</td>
                <td>{alarm.target}</td>
                <td>{alarm.severity}</td>
                <td>{alarm.timestamp}</td>
              </tr>
            ))}
          </tbody>
        </table>
      );
    }

    if (tableId === 'historical_events_table') {
      return (
        <table className="hd-table" data-testid="activity-table">
          <thead>
            <tr>
              <th>Event ID</th>
              <th>Source</th>
              <th>Message</th>
              <th>Timestamp</th>
            </tr>
          </thead>
          <tbody>
            {activityEvents.map((event) => (
              <tr key={event.eventId}>
                <td>{event.eventId}</td>
                <td>{event.source}</td>
                <td>{event.message}</td>
                <td>{event.timestamp}</td>
              </tr>
            ))}
          </tbody>
        </table>
      );
    }

    return null;
  };

  // --- RECURSIVE PARSER ENGINE ---
  const renderComponent = (node: any): React.ReactNode => {
    switch (node.type) {
      case 'SidebarLayout': {
        const sidebarChild = node.children.find((c: any) => c.type === 'HierarchyTreeSelector');
        const splitWorkspaceChild = node.children.find((c: any) => c.type === 'SplitWorkspace');
        return (
          <div className="layout-container" ref={containerRef}>
            {sidebarChild && renderComponent(sidebarChild)}
            <div
              className="vertical-splitter-bar"
              onPointerDown={handleSidebarPointerDown}
              onPointerMove={handleSidebarPointerMove}
              onPointerUp={handleSidebarPointerUp}
            >
              <div className="vertical-splitter-handle"></div>
            </div>
            {splitWorkspaceChild && renderComponent(splitWorkspaceChild)}
          </div>
        );
      }

      case 'HierarchyTreeSelector': {
        return (
          <aside className="sidebar-nav" key={node.id} style={{ width: `${sidebarWidth}px` }}>
            <div className="sidebar-header">
              <svg className="outline-svg brand-icon" viewBox="0 0 24 24">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
              </svg>
              <h2>Antigravity Console</h2>
            </div>
            <nav
              className="nav-menu"
              tabIndex={0}
              onKeyDown={handleKeyDown}
              style={{ outline: 'none' }}
              role="tree"
              aria-label="Hierarchy Navigation"
            >
              <ul className="tree-list">{treeData.map(renderNode)}</ul>
            </nav>
            <div className="sidebar-footer">
              <div className="worker-status">
                <span className="status-dot pulsing"></span>
                <span>Worker: {workerResult !== null ? workerResult : 'Idle'}</span>
              </div>
              <div className="theme-selector-container">
                <svg className="theme-icon" viewBox="0 0 24 24">
                  <path d="M12 2A10 10 0 0 0 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10A10 10 0 0 0 12 2zm1 17.93V4.07a8 8 0 0 1 0 15.86z" />
                </svg>
                <select
                  className="theme-select"
                  value={theme}
                  onChange={(e) => setTheme(e.target.value)}
                >
                  <option value="light">Light</option>
                  <option value="dark">Dark</option>
                  <option value="system">System</option>
                </select>
              </div>
            </div>
          </aside>
        );
      }

      case 'SplitWorkspace': {
        const topoChild = node.children.find((c: any) => c.type === 'TopographicalView');
        const tabbedChild = node.children.find((c: any) => c.type === 'TabbedContainer');
        return (
          <main className="main-content" key={node.id}>
            {/* Topographical Viewport Area */}
            <section
              className="pane top-pane reflow-isolated"
              style={{ height: `${splitterHeight}px` }}
            >
              {topoChild && renderComponent(topoChild)}
            </section>

            {/* Splitter Resizing handle */}
            <div
              className="splitter-bar"
              onPointerDown={handlePointerDown}
              onPointerMove={handlePointerMove}
              onPointerUp={handlePointerUp}
            >
              <div className="splitter-handle"></div>
            </div>

            {/* Bottom Tabbed Area */}
            <section className="pane bottom-pane reflow-isolated">
              {tabbedChild && renderComponent(tabbedChild)}
            </section>
          </main>
        );
      }

      case 'TopographicalView': {
        return (
          <div
            style={{ display: 'flex', flexDirection: 'column', height: '100%' }}
            key={node.id}
          >
            <div className="pane-header">
              <h3>Active View: {currentView}</h3>
              {/* Responsive Navigation Breadcrumbs */}
              <NavigationBreadcrumbs items={getBreadcrumbsItems(currentView)} />
            </div>
            <div
              ref={topoContainerRef}
              className="pane-body"
              style={{ padding: 0, display: 'flex', flexDirection: 'column', flexGrow: 1, minHeight: 0, overflow: 'hidden' }}
            >
              {/* GPGPU Topology Canvas Viewport wrapper */}
              <div style={{ height: children ? `${topoMapHeight}px` : '100%', position: 'relative', overflow: 'hidden', flexShrink: 0 }}>
                <TopologyMap
                  activeFocusedNode={currentView}
                  onNodeSelect={(nodeId: string) => {
                    if (onViewChange) onViewChange(nodeId);
                  }}
                />
              </div>

              {/* Adjustable Splitter between Topology Map and PropertyGrid */}
              {children && (
                <div
                  className="splitter-bar"
                  onPointerDown={handleTopoPointerDown}
                  onPointerMove={handleTopoPointerMove}
                  onPointerUp={handleTopoPointerUp}
                >
                  <div className="splitter-handle"></div>
                </div>
              )}

              {/* Fallback to render children if passed directly */}
              {children && <div style={{ padding: '24px', overflowY: 'auto', flex: 1, minHeight: 0 }}>{children}</div>}
            </div>
          </div>
        );
      }

      case 'TabbedContainer': {
        const labelMap: Record<string, string> = {
          sub_elements_table: 'Items',
          active_alarms_table: 'Status',
          historical_events_table: 'Activity',
        };

        const tabs = node.children.map((child: any) => {
          const id = child.id;
          const label = labelMap[id] || child.props?.label || id;
          return { id, label, child };
        });

        const activeTab = tabs.find((t: any) => t.id === activeTabId) || tabs[0];

        return (
          <div
            style={{ display: 'flex', flexDirection: 'column', height: '100%' }}
            key={node.id}
          >
            {/* Tab selection bar */}
            <div className="tab-bar" role="tablist">
              {tabs.map((tab: any) => (
                <button
                  key={tab.id}
                  className={`tab-item ${activeTabId === tab.id ? 'active' : ''}`}
                  role="tab"
                  aria-selected={activeTabId === tab.id}
                  onClick={() => setActiveTabId(tab.id)}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {/* Selected tab table body */}
            <div className="pane-body hd-table-container">
              {activeTab && renderComponent(activeTab.child)}
            </div>
          </div>
        );
      }

      case 'TableView': {
        return (
          <div key={node.id} style={{ height: '100%' }}>
            {renderTableContent(node.id)}
          </div>
        );
      }

      default:
        return null;
    }
  };

  return <>{renderComponent(logicalLayout.layout.root_container)}</>;
};
