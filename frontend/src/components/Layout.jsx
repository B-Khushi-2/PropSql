import { useState } from 'react'

export const ROLES = {
  property_manager: {
    id: 'property_manager',
    name: 'Property Manager',
    icon: '🏢',
    badge: 'Operations',
    description: 'Full portfolio, revenue collection, occupancy, and operational reporting access.',
    views: ['dashboard', 'properties', 'units', 'tenants', 'leases', 'payments', 'maintenance', 'reports', 'audit_logs']
  },
  support_engineer: {
    id: 'support_engineer',
    name: 'Support Engineer',
    icon: '🛠️',
    badge: 'SQL Support & Diagnostics',
    description: 'Access to SQL support cases, PostgreSQL execution plans, audit logs, and validation tests.',
    views: ['dashboard', 'reports', 'support', 'performance', 'audit_logs']
  },
  tenant: {
    id: 'tenant',
    name: 'Tenant Resident',
    icon: '👤',
    badge: 'Resident Portal',
    description: 'Personal payment ledger, lease details, and maintenance ticket tracking.',
    views: ['payments', 'maintenance', 'reports']
  },
  vendor: {
    id: 'vendor',
    name: 'Vendor / Technician',
    icon: '🔧',
    badge: 'Field Ops',
    description: 'Work order dispatch, materials tracking, and service request resolution.',
    views: ['maintenance', 'reports']
  }
}

const navigation = [
  ['dashboard', 'Dashboard', '🏢🛠️'], 
  ['properties', 'Properties', '🏢'], 
  ['units', 'Units', '🏢'], 
  ['tenants', 'Tenants', '🏢'],
  ['leases', 'Leases', '🏢'], 
  ['payments', 'Payments', '🏢👤'], 
  ['maintenance', 'Maintenance', '🏢👤🔧'], 
  ['reports', 'Reports', '🏢🛠️👤🔧'],
  ['audit_logs', 'Audit Logs', '🏢🛠️'],
  ['support', 'SQL Support', '🛠️'], 
  ['performance', 'Query Performance', '🛠️']
]

export default function Layout({ page, onNavigate, title, subtitle, children }) {
  const [activeRole, setActiveRole] = useState('property_manager')
  const [showRoleModal, setShowRoleModal] = useState(false)

  const currentRole = ROLES[activeRole]

  const handleRoleSelect = (roleId) => {
    setActiveRole(roleId)
    localStorage.setItem('propsql_active_role', roleId)
    setShowRoleModal(false)
    const allowed = ROLES[roleId].views
    if (!allowed.includes(page)) {
      onNavigate(allowed[0])
    }
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <button className="brand" onClick={() => onNavigate(currentRole.views[0])}>
          <span className="brand-mark">PS</span>
          <span>
            <strong>PropSQL</strong>
            <small>Property operations</small>
          </span>
        </button>
        <div className="role-sidebar-badge">
          <span>{currentRole.icon} {currentRole.name}</span>
          <small>{currentRole.badge}</small>
        </div>
        <nav aria-label="Primary navigation">
          {navigation
            .filter(([id]) => currentRole.views.includes(id))
            .map(([id, label]) => (
              <button 
                key={id} 
                className={page === id ? 'active' : ''}
                onClick={() => onNavigate(id)}
              >
                <span className="nav-indicator" />
                {label}
              </button>
            ))
          }
        </nav>
        <div className="sidebar-foot">
          <span className="database-dot" />PostgreSQL workspace
          <small>Role: {currentRole.name}</small>
        </div>
      </aside>

      <main className="main-area">
        <header className="topbar">
          <div>
            <p className="eyebrow">Property Management SQL Support & Reporting</p>
            <h1>{title}</h1>
            {subtitle && <p className="subtitle">{subtitle}</p>}
          </div>

          <div className="user-profile-controls">
            <div className="active-user-pill" title="Current session identity">
              <span className="user-avatar">{currentRole.icon}</span>
              <div className="user-details">
                <strong>{currentRole.name}</strong>
                <small>{currentRole.badge}</small>
              </div>
            </div>

            <button 
              className="role-switch-btn" 
              onClick={() => setShowRoleModal(true)}
              title="Switch user role or log out of session"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
              Logout / Switch Role
            </button>
          </div>
        </header>

        <div className="content">
          {children}
        </div>

        {showRoleModal && (
          <div className="role-modal-backdrop" onClick={() => setShowRoleModal(false)}>
            <div className="role-modal-card" onClick={e => e.stopPropagation()}>
              <div className="role-modal-header">
                <div>
                  <h2>Select Operational Role</h2>
                  <p>Transverse between user personas to test role scopes and permissions</p>
                </div>
                <button className="modal-close-btn" onClick={() => setShowRoleModal(false)}>✕</button>
              </div>
              <div className="role-options-grid">
                {Object.values(ROLES).map(r => (
                  <div 
                    key={r.id} 
                    className={`role-option-card ${activeRole === r.id ? 'active-role' : ''}`}
                    onClick={() => handleRoleSelect(r.id)}
                  >
                    <div className="role-option-top">
                      <span className="role-icon-large">{r.icon}</span>
                      <div>
                        <h3>{r.name}</h3>
                        <span className="role-tag">{r.badge}</span>
                      </div>
                    </div>
                    <p>{r.description}</p>
                    <div className="role-scope-list">
                      <small>Scope:</small> {r.views.join(', ')}
                    </div>
                    {activeRole === r.id ? (
                      <span className="active-check">✓ Active Role</span>
                    ) : (
                      <button className="select-role-btn">Switch to this Role</button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}

