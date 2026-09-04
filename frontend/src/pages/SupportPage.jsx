import { useEffect, useState } from 'react'
import { apiRequest } from '../api'
import { ErrorState, LoadingState } from '../components/Feedback'

const labels = { problem: 'Problem', investigation_sql: 'Investigation', expected_result: 'Expected result', actual_result: 'Actual result', root_cause: 'Root cause', fix: 'Fix', validation_sql: 'Validation' }

function CaseSection({ name, body, index }) {
  const lines = body.split('\n'); const textLines = lines.filter((line) => line.trim().startsWith('--')).map((line) => line.replace(/^--\s?/, '')).join(' ')
  const sqlLines = lines.filter((line) => !line.trim().startsWith('--')).join('\n').trim()
  return <section className="case-step"><span className="step-number">{String(index + 1).padStart(2,'0')}</span><div><h3>{labels[name] || name.replaceAll('_',' ')}</h3>{textLines && <p>{textLines}</p>}{sqlLines && <pre><code>{sqlLines}</code></pre>}</div></section>
}

export default function SupportPage() {
  const [cases, setCases] = useState(null); const [selected, setSelected] = useState(null); const [detail, setDetail] = useState(null); const [error, setError] = useState('')
  useEffect(() => { apiRequest('/support/cases').then((items) => { setCases(items); setSelected(items[0]?.id) }).catch((err) => setError(err.message)) }, [])
  useEffect(() => { if (selected) { setDetail(null); apiRequest(`/support/cases/${selected}`).then(setDetail).catch((err) => setError(err.message)) } }, [selected])
  if (error) return <ErrorState message={error} />
  if (!cases) return <LoadingState label="Loading support case library" />
  return <div className="support-layout"><aside className="case-list"><div><p className="eyebrow">Case queue</p><h2>SQL investigations</h2><p>{cases.length} documented incidents</p></div>{cases.map((item) => <button key={item.id} className={selected === item.id ? 'active' : ''} onClick={() => setSelected(item.id)}><span>CASE-{String(item.id).padStart(2,'0')}</span><strong>{item.title}</strong><small className={`severity ${item.severity.toLowerCase()}`}>{item.severity}</small></button>)}</aside>
    <article className="panel case-detail">{!detail ? <LoadingState label="Opening case" /> : <><header><div><p className="eyebrow">CASE-{String(detail.id).padStart(2,'0')} · {detail.severity} severity</p><h2>{detail.title}</h2></div><span className="sql-file">{detail.filename}</span></header>{Object.entries(detail.sections).map(([name, body], index) => <CaseSection key={name} name={name} body={body} index={index} />)}</>}</article></div>
}
