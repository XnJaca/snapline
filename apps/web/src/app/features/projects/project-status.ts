import type { ChipTone } from '../../shared/chip/chip';

const TONE: Record<string, ChipTone> = {
  LEAD: 'neutral',
  ESTIMATED: 'neutral',
  SCHEDULED: 'info',
  IN_PROGRESS: 'info',
  COMPLETED: 'success',
  ON_HOLD: 'warning',
  CANCELLED: 'danger',
};

export function projectStatusTone(status: string): ChipTone {
  return TONE[status] ?? 'neutral';
}
