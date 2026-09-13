// Formatting helpers for the metrics collector.

const UNITS = {
  B: 1,
  KB: 1024,
  MB: 1024 ** 2,
  GB: 1024 ** 3,
};

/**
 * Parse a size string like "4KB" or "1.5GB" into a byte count.
 */
export function parseBytes(str) {
  const match = /^([0-9]*\.?[0-9]+)\s*(B|KB|MB|GB)$/.exec(String(str).trim());
  if (!match) throw new Error(`unparseable size: ${str}`);
  return Math.round(Number(match[1]) * UNITS[match[2]]);
}

/**
 * Render a millisecond duration as "1h 2m 3s".
 */
export function formatDuration(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;

  const parts = [];
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  parts.push(`${seconds}s`);
  return parts.join(' ');
}
