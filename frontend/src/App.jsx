import { useEffect, useState } from 'react'
import Layout from './components/Layout'
import DashboardPage from './pages/DashboardPage'
import EntityPage, { entityConfig } from './pages/EntityPage'
import ReportsPage from './pages/ReportsPage'
import SupportPage from './pages/SupportPage'
import PerformancePage from './pages/PerformancePage'
import AuditLogsPage from './pages/AuditLogsPage'

const pageMeta = {
  dashboard: ['Operations dashboard', 'Portfolio health, collections, lease risk, and maintenance workload.'],
  reports: ['Reports', 'Operational reporting calculated in PostgreSQL.'],
  audit_logs: ['Audit Trail', 'Automated JSONB change logs captured by PostgreSQL triggers.'],
  support: ['SQL Support', 'Documented troubleshooting from symptom to validated fix.'],
  performance: ['Query Performance', 'Live PostgreSQL plan comparisons and indexing decisions.'],
  ...Object.fromEntries(Object.entries(entityConfig).map(([key, value]) => [key, [value.title, value.subtitle]])),
}

function getPageFromHash() { const value = window.location.hash.replace('#/',''); return pageMeta[value] ? value : 'dashboard' }

export default function App() {
  const [page, setPage] = useState(getPageFromHash)
  useEffect(() => { const handler = () => setPage(getPageFromHash()); window.addEventListener('hashchange', handler); return () => window.removeEventListener('hashchange', handler) }, [])
  const navigate = (next) => { window.location.hash = `/${next}`; setPage(next) }
  let content
  if (page === 'dashboard') content = <DashboardPage />
  else if (entityConfig[page]) content = <EntityPage entity={page} />
  else if (page === 'reports') content = <ReportsPage />
  else if (page === 'audit_logs') content = <AuditLogsPage />
  else if (page === 'support') content = <SupportPage />
  else content = <PerformancePage />
  return <Layout page={page} onNavigate={navigate} title={pageMeta[page][0]} subtitle={pageMeta[page][1]}>{content}</Layout>
}
