import React, { useState } from 'react';
import { Layout } from './components/layout';
import { PropertyGrid } from './components/property-grid';

export const App: React.FC = () => {
  const [activeView, setActiveView] = useState('Ingestion');

  return (
    <Layout activeView={activeView} onViewChange={setActiveView}>
      <PropertyGrid activeView={activeView} />
    </Layout>
  );
};
