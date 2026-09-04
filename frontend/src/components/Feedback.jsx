export function LoadingState({ label = 'Loading data' }) {
  return <div className="feedback"><span className="spinner" />{label}…</div>
}

export function ErrorState({ message, onRetry }) {
  return <div className="error-panel"><strong>Data could not be loaded</strong><p>{message}</p>{onRetry && <button onClick={onRetry}>Try again</button>}</div>
}

export function EmptyState({ label = 'No records match the current filters.' }) {
  return <div className="feedback">{label}</div>
}
