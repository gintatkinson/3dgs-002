/**
 * @realizes UML::ContextualPanel
 *
 * ContextualPanel is a slide-out contextual side drawer panel.
 * It closes when the user presses the 'Escape' key or clicks outside.
 *
 * Properties:
 * - isOpen: boolean
 * - onClose: () => void
 * - title?: string
 */

import React, { useEffect, useRef } from 'react';

export interface ContextualPanelProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children?: React.ReactNode;
}

/**
 * ContextualPanel Component
 *
 * @param props - The properties for the ContextualPanel component.
 * @returns The rendered contextual side panel component.
 */
export const ContextualPanel: React.FC<ContextualPanelProps> = ({
  isOpen,
  onClose,
  title,
  children,
}) => {
  const panelRef = useRef<HTMLDivElement>(null);

  // Close on Escape key press
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div
      className="contextual-panel-overlay"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.4)',
        backdropFilter: 'blur(4px)',
        zIndex: 1000,
        display: 'flex',
        justifyContent: 'flex-end',
      }}
      onClick={(e) => {
        // Close when clicking outside of the panel content
        if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
          onClose();
        }
      }}
    >
      <div
        ref={panelRef}
        className="contextual-panel-content"
        style={{
          width: '400px',
          height: '100%',
          backgroundColor: '#1f2937', // Sleek dark surface color
          color: '#f9fafb',
          boxShadow: '-4px 0 25px rgba(0, 0, 0, 0.5)',
          display: 'flex',
          flexDirection: 'column',
          animation: 'slideIn 0.3s ease-out',
        }}
      >
        <style>
          {`
            @keyframes slideIn {
              from { transform: translateX(100%); }
              to { transform: translateX(0); }
            }
          `}
        </style>
        <div
          className="contextual-panel-header"
          style={{
            padding: '16px',
            borderBottom: '1px solid #374151',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <h3 style={{ margin: 0, fontSize: '16px', fontWeight: 600 }}>
            {title || 'Details'}
          </h3>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              color: '#9ca3af',
              cursor: 'pointer',
              fontSize: '20px',
              padding: '4px 8px',
              borderRadius: '4px',
            }}
            aria-label="Close panel"
          >
            &times;
          </button>
        </div>
        <div
          className="contextual-panel-body"
          style={{
            padding: '16px',
            flex: 1,
            overflowY: 'auto',
          }}
        >
          {children}
        </div>
      </div>
    </div>
  );
};
