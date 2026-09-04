import { useEffect, useState } from 'react'
import { apiRequest } from '../api'
import { ErrorState, LoadingState } from '../components/Feedback'

function Plan({ title, sql, plan, tone }) {
  return <div className={`plan-card ${tone}`}><div className="plan-label">{title}</div><h3>SQL query</h3><pre><code>{sql}</code></pre><h3>PostgreSQL execution plan</h3><pre className="plan-output"><code>{JSON.stringify(plan, null, 2)}</code></pre></div>
}

export default function PerformancePage() {
  const [examples, setExamples] = useState(null); const [error, setError] = useState('')
  const load = () => { setError(''); apiRequest('/performance').then(setExamples).catch((err) => setError(err.message)) }
  useEffect(load, [])
  if (error) return <ErrorState message={error} onRetry={load} />
  if (!examples) return <LoadingState label="Requesting live PostgreSQL plans" />
  return <div className="performance-list"><div className="notice"><strong>Plan-based comparison</strong><span>No benchmark numbers are hardcoded. These plans are produced by the connected PostgreSQL database when this page loads.</span></div>{examples.map((item, index) => <section className="panel performance-case" key={item.id}><header><span>{String(index + 1).padStart(2,'0')}</span><div><h2>{item.title}</h2><p>{item.issue}</p></div><code>{item.index}</code></header><div className="plan-grid"><Plan title="Before optimization" sql={item.before_sql} plan={item.before_plan} tone="before" /><Plan title="After optimization" sql={item.after_sql} plan={item.after_plan} tone="after" /></div></section>)}</div>
}
