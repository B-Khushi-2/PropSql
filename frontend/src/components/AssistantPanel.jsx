import { useState } from 'react'
import { apiRequest } from '../api'
import DataTable from './DataTable'

const examples = [
  'Which properties have occupancy below 80%?',
  'Which leases expire in the next 30 days?',
  'Which tenants have pending payments?',
  'Show the top 5 properties by rent collection.',
  'Find duplicate payments.',
]

export default function AssistantPanel() {
  const [question, setQuestion] = useState(examples[0])
  const [answer, setAnswer] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function submit(event) {
    event.preventDefault()
    setLoading(true); setError('')
    try { setAnswer(await apiRequest('/assistant', { method: 'POST', body: JSON.stringify({ question }) })) }
    catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  return <section className="assistant-panel">
    <div className="section-heading"><div><p className="eyebrow">Read-only query helper</p><h2>Support assistant</h2><p>Uses a small approved query catalog. It never generates or executes write statements.</p></div><span className="read-only-label">SELECT only</span></div>
    <form onSubmit={submit} className="assistant-form"><input aria-label="Database question" value={question} onChange={(e) => setQuestion(e.target.value)} /><button disabled={loading}>{loading ? 'Running…' : 'Run report'}</button></form>
    <div className="example-questions">{examples.map((item) => <button key={item} onClick={() => setQuestion(item)}>{item}</button>)}</div>
    {error && <p className="inline-error">{error}</p>}
    {answer && <div className="assistant-result"><p>{answer.explanation}</p><details open><summary>SQL executed</summary><pre><code>{answer.sql}</code></pre></details><DataTable rows={answer.rows} pageSize={8} /></div>}
  </section>
}
