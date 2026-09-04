const API_BASE = import.meta.env.VITE_API_URL || 'https://propsql.onrender.com/api'

export async function apiRequest(path, options = {}) {
  const activeRole = localStorage.getItem('propsql_active_role') || 'property_manager'
  let response
  try {
    response = await fetch(`${API_BASE}${path}`, {
      headers: {
        'Content-Type': 'application/json',
        'X-User-Role': activeRole,
        'X-Tenant-ID': '1',
        ...options.headers,
      },
      ...options,
    })
  } catch {
    throw new Error('Unable to reach the PropSQL API. Confirm the Flask service is running.')
  }
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(body.error || `Request failed with status ${response.status}.`)
  return body
}
