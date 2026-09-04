const tones = {
  active: 'success', occupied: 'success', paid: 'success', closed: 'success', completed: 'success',
  pending: 'warning', partial: 'warning', assigned: 'info', scheduled: 'info', in_progress: 'info',
  late: 'danger', emergency: 'danger', high: 'danger', expired: 'muted', vacant: 'muted',
  open: 'warning', low: 'muted', medium: 'info', terminated: 'danger', cancelled: 'muted',
}

export default function StatusBadge({ value }) {
  const label = String(value ?? '—').replaceAll('_', ' ')
  return <span className={`status-badge ${tones[value] || 'muted'}`}>{label}</span>
}
