import { useMemo, useState } from 'react'
import { EmptyState } from './Feedback'
import StatusBadge from './StatusBadge'

const isStatus = (key) => key.includes('status') || key === 'priority'
const isMoney = (key) => /rent|amount|balance|cost|rate$/.test(key) && !key.includes('percentage')
const isDate = (key) => key.includes('date') || key.endsWith('_at')

function displayValue(key, value) {
  if (value === null || value === undefined || value === '') return '—'
  if (isMoney(key) && !Number.isNaN(Number(value))) return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(Number(value))
  if (key.includes('percentage')) return `${Number(value).toFixed(1)}%`
  if (isDate(key)) {
    const date = new Date(value)
    if (!Number.isNaN(date.getTime())) return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
  }
  return String(value)
}

export default function DataTable({ rows = [], columns, searchable = true, pageSize = 12 }) {
  const [search, setSearch] = useState('')
  const [sort, setSort] = useState({ key: columns?.[0]?.key || '', direction: 'asc' })
  const [page, setPage] = useState(1)
  const visibleColumns = columns || (rows[0] ? Object.keys(rows[0]).map((key) => ({ key, label: key.replaceAll('_', ' ') })) : [])

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()
    const result = !term ? [...rows] : rows.filter((row) => Object.values(row).some((value) => String(value ?? '').toLowerCase().includes(term)))
    if (sort.key) result.sort((a, b) => {
      const left = a[sort.key] ?? ''
      const right = b[sort.key] ?? ''
      const comparison = !Number.isNaN(Number(left)) && !Number.isNaN(Number(right))
        ? Number(left) - Number(right)
        : String(left).localeCompare(String(right))
      return sort.direction === 'asc' ? comparison : -comparison
    })
    return result
  }, [rows, search, sort])

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize))
  const currentPage = Math.min(page, pageCount)
  const shown = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize)
  const toggleSort = (key) => {
    setSort((current) => ({ key, direction: current.key === key && current.direction === 'asc' ? 'desc' : 'asc' }))
    setPage(1)
  }

  return <div className="table-shell">
    {searchable && <div className="table-toolbar">
      <label className="search-field"><span>Search records</span><input value={search} onChange={(event) => { setSearch(event.target.value); setPage(1) }} placeholder="Type to filter…" /></label>
      <span className="record-count">{filtered.length} records</span>
    </div>}
    {!shown.length ? <EmptyState /> : <div className="table-scroll"><table>
      <thead><tr>{visibleColumns.map((column) => <th key={column.key}><button className="sort-button" onClick={() => toggleSort(column.key)}>{column.label}{sort.key === column.key ? (sort.direction === 'asc' ? ' ↑' : ' ↓') : ''}</button></th>)}</tr></thead>
      <tbody>{shown.map((row, rowIndex) => <tr key={row.id || row.payment_id || row.lease_id || row.request_id || row.property_id || row.unit_id || row.tenant_id || rowIndex}>
        {visibleColumns.map((column) => <td key={column.key} className={column.align === 'right' ? 'align-right' : ''}>{column.render ? column.render(row[column.key], row) : isStatus(column.key) ? <StatusBadge value={row[column.key]} /> : displayValue(column.key, row[column.key])}</td>)}
      </tr>)}</tbody>
    </table></div>}
    {pageCount > 1 && <div className="pagination"><button disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)}>Previous</button><span>Page {currentPage} of {pageCount}</span><button disabled={currentPage === pageCount} onClick={() => setPage(currentPage + 1)}>Next</button></div>}
  </div>
}
