import { useEffect, useMemo, useState } from 'react'
import { apiRequest } from '../api'
import DataTable from '../components/DataTable'
import { ErrorState, LoadingState } from '../components/Feedback'

const reports = [
  ['occupancy','Occupancy','/reports/occupancy'], ['rent','Rent collection','/reports/rent-collection'],
  ['expiry','Lease expiry','/reports/lease-expiry'], ['maintenance','Maintenance','/reports/maintenance'],
  ['performance','Property performance','/reports/property-performance'], ['payments','Tenant payment history','/reports/tenant-payment-history'],
  ['delinquent','Delinquent tenants','/reports/delinquent-tenants'],
]

const ROLE_ALLOWED_REPORTS = {
  property_manager: ['occupancy', 'rent', 'expiry', 'maintenance', 'performance', 'payments', 'delinquent'],
  support_engineer: ['occupancy', 'rent', 'expiry', 'maintenance', 'performance', 'payments', 'delinquent'],
  tenant: ['payments', 'maintenance'],
  vendor: ['maintenance']
}

export default function ReportsPage() {
  const activeRole = localStorage.getItem('propsql_active_role') || 'property_manager'
  const allowedReportIds = ROLE_ALLOWED_REPORTS[activeRole] || ROLE_ALLOWED_REPORTS.property_manager
  const availableReports = useMemo(() => reports.filter(([id]) => allowedReportIds.includes(id)), [allowedReportIds])

  const [selected, setSelected] = useState(() => availableReports[0]?.[0] || 'occupancy')
  const [rows, setRows] = useState(null)
  const [error, setError] = useState('')
  const [days, setDays] = useState(30)
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7))

  const activeSelected = availableReports.some(([id]) => id === selected) ? selected : (availableReports[0]?.[0] || 'occupancy')
  const report = useMemo(() => availableReports.find(([id]) => id === activeSelected) || availableReports[0], [availableReports, activeSelected])

  const load = () => {
    if (!report) return
    setRows(null); setError('')
    let path = report[2]
    if (report[0] === 'expiry') path += `?days=${days}`
    if (report[0] === 'rent') path += `?month=${month}-01`
    apiRequest(path).then(setRows).catch((err) => setError(err.message))
  }

  useEffect(load, [report, days, month])

  if (!report) return <ErrorState message="No reports are accessible for this role." />

  return (
    <div className="reports-layout">
      <aside className="report-menu">
        <h2>Report library</h2>
        <p>SQL-driven operational views</p>
        {availableReports.map(([id, label]) => (
          <button 
            className={activeSelected === id ? 'active' : ''} 
            key={id} 
            onClick={() => setSelected(id)}
          >
            {label}
          </button>
        ))}
      </aside>
      <section className="panel report-output">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Production report</p>
            <h2>{report[1]}</h2>
            <p>Results are calculated by PostgreSQL and returned through the Flask API.</p>
          </div>
          <div className="report-filters">
            {report[0] === 'expiry' && (
              <label>
                Window
                <select value={days} onChange={(e) => setDays(Number(e.target.value))}>
                  <option value="30">30 days</option>
                  <option value="60">60 days</option>
                  <option value="90">90 days</option>
                </select>
              </label>
            )}
            {report[0] === 'rent' && (
              <label>
                Due month
                <input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
              </label>
            )}
          </div>
        </div>
        {error ? <ErrorState message={error} onRetry={load} /> : !rows ? <LoadingState label="Running SQL report" /> : <DataTable rows={rows} pageSize={15} />}
      </section>
    </div>
  )
}
