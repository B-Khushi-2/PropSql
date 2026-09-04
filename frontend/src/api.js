const API_BASE = '/api'

export async function apiRequest(path, options = {}) {
  const activeRole = localStorage.getItem('propsql_active_role') || 'property_manager'
  let response
  try {
    const separator = path.includes('?') ? '&' : '?'
    const fullUrl = `${API_BASE}${path}${separator}role=${encodeURIComponent(activeRole)}`
    response = await fetch(fullUrl, {
      headers: {
        ...options.headers,
      },
      ...options,
    })
  } catch (err) {
    console.error('Fetch execution error:', err)
    throw new Error(`Unable to reach the PropSQL API (${err.message || 'NetworkError'}). Confirm the Flask service is running.`)
  }
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(body.error || `Request failed with status ${response.status}.`)
  return body
}
