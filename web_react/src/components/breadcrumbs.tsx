/**
 * @realizes UML::NavigationBreadcrumbs
 *
 * NavigationBreadcrumbs renders a responsive path trace of the current location/view.
 * It automatically collapses middle segments into a clickable ellipsis when the path length exceeds maxItems.
 *
 * Properties:
 * - items: BreadcrumbItem[]
 * - maxItems: number
 */

import React, { useState } from 'react';

export interface BreadcrumbItem {
  id: string;
  label: string;
  onClick?: () => void;
}

export interface BreadcrumbsProps {
  items: BreadcrumbItem[];
  maxItems?: number;
}

/**
 * NavigationBreadcrumbs Component
 *
 * @param props - The properties for the NavigationBreadcrumbs component.
 * @returns The rendered breadcrumbs component.
 */
export const NavigationBreadcrumbs: React.FC<BreadcrumbsProps> = ({
  items,
  maxItems = 4,
}) => {
  const [isExpanded, setIsExpanded] = useState<boolean>(false);

  if (!items || items.length === 0) {
    return null;
  }

  const shouldCollapse = items.length > maxItems && !isExpanded;

  let renderedItems = items;
  if (shouldCollapse) {
    const first = items[0];
    const lastItems = items.slice(items.length - (maxItems - 1));
    renderedItems = [
      first,
      {
        id: 'ellipsis',
        label: '...',
        onClick: () => setIsExpanded(true),
      },
      ...lastItems,
    ];
  }

  return (
    <nav className="breadcrumbs" aria-label="Breadcrumbs">
      <ol
        className="breadcrumbs-list"
        style={{
          display: 'flex',
          alignItems: 'center',
          listStyle: 'none',
          padding: 0,
          margin: 0,
        }}
      >
        {renderedItems.map((item, index) => {
          const isLast = index === renderedItems.length - 1;
          const isEllipsis = item.id === 'ellipsis';

          return (
            <li
              key={item.id}
              className="breadcrumb-item"
              style={{ display: 'flex', alignItems: 'center' }}
            >
              {index > 0 && (
                <span
                  className="breadcrumb-separator"
                  style={{
                    margin: '0 8px',
                    color: 'var(--text-secondary, #666)',
                    userSelect: 'none',
                  }}
                >
                  /
                </span>
              )}
              {isEllipsis ? (
                <button
                  className="breadcrumb-ellipsis-btn"
                  onClick={item.onClick}
                  style={{
                    background: 'rgba(255, 255, 255, 0.08)',
                    border: 'none',
                    padding: '2px 8px',
                    cursor: 'pointer',
                    borderRadius: '4px',
                    color: 'var(--text-secondary, #9aa0a6)',
                    fontSize: '13px',
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                  aria-label="Expand breadcrumbs"
                >
                  {item.label}
                </button>
              ) : isLast ? (
                <span
                  className="breadcrumb-current"
                  style={{
                    fontWeight: 600,
                    color: 'var(--text-primary, var(--alias-color-surface, #eee))',
                    fontSize: '13px',
                  }}
                  aria-current="page"
                >
                  {item.label}
                </span>
              ) : (
                <button
                  className="breadcrumb-link"
                  onClick={item.onClick}
                  style={{
                    background: 'none',
                    border: 'none',
                    padding: 0,
                    cursor: 'pointer',
                    color: 'var(--accent-color, var(--alias-color-brand-primary, #0056b3))',
                    fontSize: '13px',
                    textDecoration: 'none',
                    fontWeight: 500,
                  }}
                >
                  {item.label}
                </button>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
};
