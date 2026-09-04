import { useEffect, useState } from 'react'
import { apiRequest } from '../api'
import DataTable from '../components/DataTable'
import { ErrorState, LoadingState } from '../components/Feedback'

export const entityConfig = {
  properties: { title: 'Properties', subtitle: 'Portfolio locations, managers, unit counts, and occupancy.', columns: [{key:'property_code',label:'Code'},{key:'property_name',label:'Property'},{key:'city',label:'City'},{key:'manager_name',label:'Manager'},{key:'total_units',label:'Units'},{key:'occupancy_percentage',label:'Occupancy'}]},
  units: { title: 'Units', subtitle: 'Unit inventory, rent position, and current operating status.', columns: [{key:'property_name',label:'Property'},{key:'unit_number',label:'Unit'},{key:'bedrooms',label:'Beds'},{key:'bathrooms',label:'Baths'},{key:'square_feet',label:'Sq ft'},{key:'market_rent',label:'Market rent'},{key:'unit_status',label:'Status'}]},
  tenants: { title: 'Tenants', subtitle: 'Tenant contact directory and lease history.', columns: [{key:'tenant_id',label:'ID'},{key:'first_name',label:'First name'},{key:'last_name',label:'Last name'},{key:'email',label:'Email'},{key:'phone',label:'Phone'},{key:'lease_count',label:'Leases'}]},
  leases: { title: 'Leases', subtitle: 'Current and historical lease agreements.', columns: [{key:'lease_id',label:'Lease'},{key:'tenant_name',label:'Tenant'},{key:'property_name',label:'Property'},{key:'unit_number',label:'Unit'},{key:'start_date',label:'Start'},{key:'end_date',label:'End'},{key:'monthly_rent',label:'Monthly rent'},{key:'lease_status',label:'Status'}]},
  payments: { title: 'Payments', subtitle: 'Rent charges, receipts, balances, and collection status.', columns: [{key:'payment_reference',label:'Reference'},{key:'tenant_name',label:'Tenant'},{key:'property_name',label:'Property'},{key:'due_date',label:'Due'},{key:'paid_date',label:'Paid'},{key:'amount_due',label:'Due amount'},{key:'amount_paid',label:'Paid amount'},{key:'payment_status',label:'Status'}]},
  maintenance: { title: 'Maintenance', subtitle: 'Resident requests, priorities, and service progress.', columns: [{key:'request_id',label:'Request'},{key:'property_name',label:'Property'},{key:'unit_number',label:'Unit'},{key:'title',label:'Issue'},{key:'priority',label:'Priority'},{key:'request_status',label:'Status'},{key:'created_at',label:'Opened'}]},
}

function CreateTicketModal({ onClose, onSuccess }) {
  const [formData, setFormData] = useState({
    unit_id: '1',
    title: '',
    description: '',
    priority: 'medium'
  })
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    setSubmitting(true)
    setFormError('')
    apiRequest('/maintenance', {
      method: 'POST',
      body: JSON.stringify(formData)
    })
      .then((res) => {
        setSubmitting(false)
        onSuccess(res.message)
      })
      .catch((err) => {
        setSubmitting(false)
        setFormError(err.message)
      })
  }

  return (
    <div className="role-modal-backdrop" onClick={onClose}>
      <div className="role-modal-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '500px' }}>
        <div className="role-modal-header">
          <div>
            <h2>Open Maintenance Request</h2>
            <p>Submits a new maintenance ticket to PostgreSQL.</p>
          </div>
          <button className="modal-close-btn" onClick={onClose}>✕</button>
        </div>
        <form onSubmit={handleSubmit} style={{ padding: '20px' }}>
          {formError && (
            <div style={{ background: '#fef2f2', border: '1px solid #fca5a5', color: '#991b1b', padding: '10px 14px', borderRadius: '6px', fontSize: '12px', marginBottom: '14px' }}>
              {formError}
            </div>
          )}
          <div style={{ marginBottom: '14px' }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155', marginBottom: '4px' }}>
              Unit ID (e.g. 1, 5, 12)
            </label>
            <input 
              type="number" 
              required 
              value={formData.unit_id} 
              onChange={(e) => setFormData({ ...formData, unit_id: e.target.value })}
              style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
            />
          </div>
          <div style={{ marginBottom: '14px' }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155', marginBottom: '4px' }}>
              Issue Summary / Title
            </label>
            <input 
              type="text" 
              required 
              value={formData.title} 
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              placeholder="e.g. Faucet leaking under kitchen sink"
              style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
            />
          </div>
          <div style={{ marginBottom: '14px' }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155', marginBottom: '4px' }}>
              Priority Level
            </label>
            <select 
              value={formData.priority} 
              onChange={(e) => setFormData({ ...formData, priority: e.target.value })}
              style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
            >
              <option value="low">Low Priority</option>
              <option value="medium">Medium Priority</option>
              <option value="high">High Priority</option>
              <option value="emergency">Emergency</option>
            </select>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
            <button 
              type="button" 
              onClick={onClose} 
              style={{ padding: '8px 16px', background: '#f1f5f9', color: '#334155', border: '1px solid #cbd5e1', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
            >
              Cancel
            </button>
            <button 
              type="submit" 
              disabled={submitting}
              style={{ padding: '8px 16px', background: '#2563eb', color: '#ffffff', border: 'none', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
            >
              {submitting ? 'Submitting...' : 'Submit Ticket'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function CreateLeaseModal({ onClose, onSuccess }) {
  const [formData, setFormData] = useState({
    unit_id: '',
    tenant_id: '',
    start_date: new Date().toISOString().slice(0, 10),
    end_date: new Date(Date.now() + 365 * 86400000).toISOString().slice(0, 10),
    monthly_rent: '1500',
    deposit_amount: '1500'
  })
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    setSubmitting(true)
    setFormError('')
    apiRequest('/leases', {
      method: 'POST',
      body: JSON.stringify(formData)
    })
      .then((res) => {
        setSubmitting(false)
        onSuccess(res.message)
      })
      .catch((err) => {
        setSubmitting(false)
        setFormError(err.message)
      })
  }

  return (
    <div className="role-modal-backdrop" onClick={onClose}>
      <div className="role-modal-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '520px' }}>
        <div className="role-modal-header">
          <div>
            <h2>Execute Write Transaction: New Lease</h2>
            <p>Runs a PostgreSQL multi-step BEGIN...COMMIT transaction with FOR UPDATE row locking.</p>
          </div>
          <button className="modal-close-btn" onClick={onClose}>✕</button>
        </div>
        <form onSubmit={handleSubmit} style={{ padding: '20px' }}>
          {formError && (
            <div style={{ background: '#fef2f2', border: '1px solid #fca5a5', color: '#991b1b', padding: '10px 14px', borderRadius: '6px', fontSize: '12px', marginBottom: '14px' }}>
              <strong>Transaction Rolled Back:</strong> {formError}
            </div>
          )}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '14px' }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155' }}>
              Unit ID (e.g. 5, 12, 20)
              <input 
                type="number" 
                required 
                value={formData.unit_id} 
                onChange={(e) => setFormData({ ...formData, unit_id: e.target.value })}
                placeholder="Unit ID"
                style={{ width: '100%', padding: '8px', marginTop: '4px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
              />
            </label>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155' }}>
              Tenant ID (e.g. 1, 4, 10)
              <input 
                type="number" 
                required 
                value={formData.tenant_id} 
                onChange={(e) => setFormData({ ...formData, tenant_id: e.target.value })}
                placeholder="Tenant ID"
                style={{ width: '100%', padding: '8px', marginTop: '4px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
              />
            </label>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '14px' }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155' }}>
              Start Date
              <input 
                type="date" 
                required 
                value={formData.start_date} 
                onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                style={{ width: '100%', padding: '8px', marginTop: '4px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
              />
            </label>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155' }}>
              End Date
              <input 
                type="date" 
                required 
                value={formData.end_date} 
                onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                style={{ width: '100%', padding: '8px', marginTop: '4px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
              />
            </label>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '18px' }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155' }}>
              Monthly Rent (₹)
              <input 
                type="number" 
                step="0.01" 
                required 
                value={formData.monthly_rent} 
                onChange={(e) => setFormData({ ...formData, monthly_rent: e.target.value })}
                style={{ width: '100%', padding: '8px', marginTop: '4px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
              />
            </label>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: '#334155' }}>
              Deposit Amount (₹)
              <input 
                type="number" 
                step="0.01" 
                required 
                value={formData.deposit_amount} 
                onChange={(e) => setFormData({ ...formData, deposit_amount: e.target.value })}
                style={{ width: '100%', padding: '8px', marginTop: '4px', borderRadius: '4px', border: '1px solid #cbd5e1' }}
              />
            </label>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
            <button 
              type="button" 
              onClick={onClose} 
              style={{ padding: '8px 16px', background: '#f1f5f9', color: '#334155', border: '1px solid #cbd5e1', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
            >
              Cancel
            </button>
            <button 
              type="submit" 
              disabled={submitting}
              style={{ padding: '8px 16px', background: '#2563eb', color: '#ffffff', border: 'none', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
            >
              {submitting ? 'Committing Transaction...' : 'Commit Transaction'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function EntityPage({ entity }) {
  const [rows, setRows] = useState(null)
  const [error, setError] = useState('')
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [showTicketModal, setShowTicketModal] = useState(false)
  const [successNotice, setSuccessNotice] = useState('')

  const activeRole = localStorage.getItem('propsql_active_role') || 'property_manager'

  const load = () => {
    setRows(null)
    setError('')
    apiRequest(`/${entity}?page_size=200`)
      .then((body) => setRows(body.data))
      .catch((err) => setError(err.message))
  }

  const handleStatusChange = (requestId, newStatus) => {
    apiRequest(`/maintenance/${requestId}/status`, {
      method: 'POST',
      body: JSON.stringify({ request_status: newStatus })
    })
      .then((res) => {
        setSuccessNotice(res.message)
        load()
      })
      .catch((err) => setError(err.message))
  }

  const handlePayPayment = (paymentId) => {
    apiRequest(`/payments/${paymentId}/pay`, { method: 'POST' })
      .then((res) => {
        setSuccessNotice(res.message)
        load()
      })
      .catch((err) => setError(err.message))
  }

  useEffect(load, [entity])

  if (error) return <ErrorState message={error} onRetry={load} />
  if (!rows) return <LoadingState label={`Loading ${entity}`} />

  // Compute dynamic columns with interactive status actions
  const columns = [...entityConfig[entity].columns]
  if (entity === 'maintenance') {
    columns.push({
      key: 'actions',
      label: 'Update Status',
      render: (_, row) => {
        const status = (row.request_status || '').toLowerCase()
        if (status === 'closed' || status === 'cancelled') return <span style={{ fontSize: '12px', color: '#94a3b8' }}>Completed</span>
        
        if (activeRole === 'vendor') {
          return (
            <div style={{ display: 'flex', gap: '4px' }}>
              {status !== 'in_progress' && (
                <button 
                  onClick={() => handleStatusChange(row.request_id, 'in_progress')}
                  style={{ background: '#3b82f6', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: '4px', fontSize: '11px', cursor: 'pointer' }}
                >
                  Start
                </button>
              )}
              <button 
                onClick={() => handleStatusChange(row.request_id, 'closed')}
                style={{ background: '#16a34a', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: '4px', fontSize: '11px', cursor: 'pointer' }}
              >
                Close
              </button>
            </div>
          )
        }

        if (activeRole === 'tenant') {
          return (
            <button 
              onClick={() => handleStatusChange(row.request_id, 'cancelled')}
              style={{ background: '#ef4444', color: '#fff', border: 'none', padding: '4px 8px', borderRadius: '4px', fontSize: '11px', cursor: 'pointer' }}
            >
              Cancel
            </button>
          )
        }

        return (
          <select 
            value={status} 
            onChange={(e) => handleStatusChange(row.request_id, e.target.value)}
            style={{ fontSize: '11px', padding: '4px 6px', borderRadius: '4px', border: '1px solid #cbd5e1', cursor: 'pointer' }}
          >
            <option value="open">open</option>
            <option value="assigned">assigned</option>
            <option value="in_progress">in_progress</option>
            <option value="on_hold">on_hold</option>
            <option value="closed">closed</option>
            <option value="cancelled">cancelled</option>
          </select>
        )
      }
    })
  }

  if (entity === 'payments') {
    columns.push({
      key: 'actions',
      label: 'Action',
      render: (_, row) => {
        const status = (row.payment_status || '').toLowerCase()
        if (status === 'paid') return <span style={{ fontSize: '12px', color: '#166534', fontWeight: '600' }}>✓ Paid</span>
        return (
          <button 
            onClick={() => handlePayPayment(row.payment_id)}
            style={{ background: '#16a34a', color: '#fff', border: 'none', padding: '4px 10px', borderRadius: '4px', fontSize: '11px', fontWeight: '600', cursor: 'pointer' }}
          >
            Pay Rent
          </button>
        )
      }
    })
  }

  return (
    <section className="panel entity-panel">
      {successNotice && (
        <div style={{ background: '#f0fdf4', border: '1px solid #86efac', color: '#166534', padding: '12px 16px', borderRadius: '6px', marginBottom: '14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>✓ {successNotice}</span>
          <button onClick={() => setSuccessNotice('')} style={{ background: 'transparent', border: 'none', color: '#166534', cursor: 'pointer', fontWeight: '700' }}>✕</button>
        </div>
      )}
      <div className="section-heading">
        <div>
          <h2>Portfolio records</h2>
          <p>Sort any column or search across the returned PostgreSQL rows.</p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {entity === 'leases' && activeRole === 'property_manager' && (
            <button 
              onClick={() => setShowCreateModal(true)}
              style={{ background: '#16a34a', color: '#ffffff', border: 'none', padding: '7px 14px', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
            >
              + Create New Lease (Write Transaction)
            </button>
          )}
          {entity === 'maintenance' && (activeRole === 'tenant' || activeRole === 'property_manager') && (
            <button 
              onClick={() => setShowTicketModal(true)}
              style={{ background: '#2563eb', color: '#ffffff', border: 'none', padding: '7px 14px', borderRadius: '6px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
            >
              + Open Maintenance Ticket
            </button>
          )}
          <span className="result-source">Live SQL result</span>
        </div>
      </div>
      <DataTable rows={rows} columns={columns} />

      {showCreateModal && (
        <CreateLeaseModal 
          onClose={() => setShowCreateModal(false)}
          onSuccess={(msg) => {
            setShowCreateModal(false)
            setSuccessNotice(msg)
            load()
          }}
        />
      )}

      {showTicketModal && (
        <CreateTicketModal 
          onClose={() => setShowTicketModal(false)}
          onSuccess={(msg) => {
            setShowTicketModal(false)
            setSuccessNotice(msg)
            load()
          }}
        />
      )}
    </section>
  )
}
