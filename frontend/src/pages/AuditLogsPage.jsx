import { useEffect, useState } from 'react'
import { apiRequest } from '../api'
import DataTable from '../components/DataTable'
import { ErrorState, LoadingState } from '../components/Feedback'

export default function AuditLogsPage() {
  const [logs, setLogs] = useState(null)
  const [error, setError] = useState('')

  const loadLogs = () => {
    setLogs(null)
    setError('')
    apiRequest('/audit-logs?page_size=100')
      .then((body) => setLogs(body.data))
      .catch((err) => setError(err.message))
  }

  useEffect(() => {
    loadLogs()
  }, [])

  if (error) return <ErrorState message={error} onRetry={loadLogs} />
  if (!logs) return <LoadingState label="Loading audit logs from PostgreSQL" />

  const columns = [
    { key: 'audit_id', label: 'Audit ID' },
    { key: 'table_name', label: 'Table' },
    { 
      key: 'action', 
      label: 'Action',
      render: (val) => {
        const bg = val === 'INSERT' ? '#dcfce7' : val === 'UPDATE' ? '#dbeafe' : '#fee2e2'
        const color = val === 'INSERT' ? '#166534' : val === 'UPDATE' ? '#1e40af' : '#991b1b'
        return <span style={{ background: bg, color, padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: '700' }}>{val}</span>
      }
    },
    { key: 'record_id', label: 'Record ID' },
    { key: 'changed_at', label: 'Timestamp' },
    {
      key: 'new_data',
      label: 'Captured JSONB Payload',
      render: (val) => (
        <pre style={{ margin: 0, fontSize: '11px', background: '#f8fafc', padding: '6px 8px', borderRadius: '4px', maxWidth: '400px', overflowX: 'auto', border: '1px solid #e2e8f0' }}>
          {JSON.stringify(val, null, 2)}
        </pre>
      )
    }
  ]

  return (
    <section className="panel entity-panel">
      <div className="section-heading">
        <div>
          <h2>PostgreSQL Automated Audit Trail</h2>
          <p>Powered by native PostgreSQL JSONB triggers on write transactions.</p>
        </div>
        <button 
          onClick={loadLogs}
          style={{ background: '#f1f5f9', border: '1px solid #cbd5e1', padding: '6px 12px', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
        >
          ↻ Refresh Audit Trail
        </button>
      </div>
      <DataTable rows={logs} columns={columns} />
    </section>
  )
}
