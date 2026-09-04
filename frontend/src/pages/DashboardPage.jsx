import { useEffect, useState } from 'react'
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { apiRequest } from '../api'
import AssistantPanel from '../components/AssistantPanel'
import DataTable from '../components/DataTable'
import { ErrorState, LoadingState } from '../components/Feedback'

const money = (value) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(Number(value || 0))

export default function DashboardPage() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  const load = () => { setError(''); apiRequest('/dashboard').then(setData).catch((err) => setError(err.message)) }
  useEffect(load, [])
  if (error) return <ErrorState message={error} onRetry={load} />
  if (!data) return <LoadingState label="Loading portfolio operations" />
  const s = data.summary
  const cards = [
    ['Total properties', s.total_properties, 'Active managed properties'], ['Total units', s.total_units, 'Across the portfolio'],
    ['Occupancy rate', `${s.occupancy_rate}%`, 'Date-valid active leases'], ['Collection rate', `${s.collection_rate}%`, 'Current due month'],
    ['Pending payments', s.pending_payments, 'Open or partial charges'], ['Open maintenance', s.open_maintenance, 'Requires operational follow-up'],
  ]
  return <>
    <section className="metric-grid">{cards.map(([label, value, note]) => <article className="metric-card" key={label}><span>{label}</span><strong>{value}</strong><small>{note}</small></article>)}</section>
    <section className="dashboard-grid">
      <article className="panel chart-panel"><div className="section-heading"><div><h2>Occupancy by property</h2><p>Lowest occupancy first; calculated from active leases.</p></div></div>
        <ResponsiveContainer width="100%" height={310}><BarChart data={data.occupancy.slice(0, 12)} margin={{ top: 8, right: 16, left: -18, bottom: 58 }}><CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e5e7eb" /><XAxis dataKey="property_code" angle={-38} textAnchor="end" tick={{ fontSize: 11, fill: '#5d6673' }} /><YAxis domain={[0, 100]} tick={{ fontSize: 11, fill: '#5d6673' }} /><Tooltip formatter={(value) => [`${value}%`, 'Occupancy']} /><Bar dataKey="occupancy_percentage" fill="#356c5a" radius={[2, 2, 0, 0]} /></BarChart></ResponsiveContainer>
      </article>
      <article className="panel collection-panel"><div className="section-heading"><div><h2>Rent collection</h2><p>Current-month portfolio summary.</p></div></div>
        <div className="collection-list">{data.rent_collection.slice().sort((a,b) => Number(a.collection_percentage || 0)-Number(b.collection_percentage || 0)).slice(0, 7).map((row) => <div key={row.property_id}><div><strong>{row.property_name}</strong><span>{money(row.collected_rent)} of {money(row.expected_rent)}</span></div><div className="progress"><i style={{ width: `${Math.min(Number(row.collection_percentage || 0),100)}%` }} /></div><b>{Number(row.collection_percentage || 0).toFixed(1)}%</b></div>)}</div>
      </article>
    </section>
    <section className="dashboard-grid equal">
      <article className="panel"><div className="section-heading"><div><h2>Recent maintenance</h2><p>Newest requests across all properties.</p></div></div><DataTable rows={data.recent_maintenance} searchable={false} pageSize={8} columns={[{key:'property_name',label:'Property'},{key:'unit_number',label:'Unit'},{key:'title',label:'Request'},{key:'priority',label:'Priority'},{key:'request_status',label:'Status'}]} /></article>
      <article className="panel"><div className="section-heading"><div><h2>Upcoming lease expirations</h2><p>Next 60 days, ordered by end date.</p></div></div><DataTable rows={data.upcoming_expirations} searchable={false} pageSize={8} columns={[{key:'tenant_name',label:'Tenant'},{key:'property_name',label:'Property'},{key:'unit_number',label:'Unit'},{key:'end_date',label:'End date'},{key:'days_remaining',label:'Days'}]} /></article>
    </section>
    <AssistantPanel />
  </>
}
