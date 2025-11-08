#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_DIR="$SCRIPT_DIR" node <<'NODE'
const { writeFileSync, mkdirSync } = require('fs');
const { resolve } = require('path');

const scriptDir = resolve(process.env.SCRIPT_DIR);

const code = `
function computeTimeline(config) {
  const flights = Array.isArray(config?.flights) ? config.flights : [];
  const adjustments = Array.isArray(config?.adjustments) ? config.adjustments : [];
  const timeZone = config?.timezone || 'UTC';
  const caps = isPlainObject(config?.dailySpendCaps) ? config.dailySpendCaps : {};

  const adjustmentsByFlight = new Map();
  for (const adj of adjustments) {
    if (!adj || !adj.flightId || !adj.timestamp) continue;
    const key = adj.flightId;
    const bucket = adjustmentsByFlight.get(key) || [];
    bucket.push(adj);
    adjustmentsByFlight.set(key, bucket);
  }

  const timelineMap = new Map();

  for (const flight of flights) {
    if (!flight?.id || !flight.startDate || !flight.endDate) {
      continue;
    }
    const baseBudget = Number(flight.baseBudget || 0);
    let effectiveEnd = flight.endDate;

    const flightAdjustments = (adjustmentsByFlight.get(flight.id) || []).slice();
    flightAdjustments.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

    const stateEvents = [];
    const budgetOverrides = new Map();

    for (const adj of flightAdjustments) {
      const localDay = toLocalDay(adj.timestamp, timeZone);
      const ts = new Date(adj.timestamp).getTime();
      if (adj.type === 'budget_override' && typeof adj.value !== 'undefined') {
        const existing = budgetOverrides.get(localDay);
        if (!existing || existing.order <= ts) {
          budgetOverrides.set(localDay, { value: Number(adj.value), order: ts });
        }
      } else if (adj.type === 'pause') {
        stateEvents.push({ day: localDay, state: 'paused', order: ts });
      } else if (adj.type === 'resume') {
        stateEvents.push({ day: localDay, state: 'active', order: ts });
      } else if (adj.type === 'end_override' && typeof adj.value === 'string') {
        if (compareDayStrings(adj.value, effectiveEnd) < 0) {
          effectiveEnd = adj.value;
        }
      }
    }

    if (compareDayStrings(effectiveEnd, flight.startDate) < 0) {
      continue;
    }

    stateEvents.sort((a, b) => {
      const cmp = compareDayStrings(a.day, b.day);
      if (cmp !== 0) return cmp;
      return a.order - b.order;
    });

    let stateIndex = 0;
    let currentState = 'active';

    for (const day of iterateDays(flight.startDate, effectiveEnd)) {
      while (stateIndex < stateEvents.length && compareDayStrings(stateEvents[stateIndex].day, day) <= 0) {
        currentState = stateEvents[stateIndex].state;
        stateIndex += 1;
      }

      let budget = baseBudget;
      const override = budgetOverrides.get(day);
      if (override) {
        budget = override.value;
      }

      if (currentState === 'paused') {
        budget = 0;
      }

      const entry = ensureDayBucket(timelineMap, day);
      entry.flights[flight.id] = {
        status: currentState,
        budget,
      };
    }
  }

  const timeline = Array.from(timelineMap.values());
  timeline.sort((a, b) => compareDayStrings(a.date, b.date));
  for (const entry of timeline) {
    const sortedFlights = Object.keys(entry.flights).sort();
    const ordered = {};
    for (const key of sortedFlights) {
      ordered[key] = entry.flights[key];
    }
    entry.flights = ordered;
  }
  applyDailyCaps(timeline, caps);
  return timeline;
}

function ensureDayBucket(timelineMap, day) {
  if (!timelineMap.has(day)) {
    timelineMap.set(day, { date: day, flights: {} });
  }
  return timelineMap.get(day);
}

function iterateDays(start, end) {
  const results = [];
  let cursor = new Date(start + 'T00:00:00Z');
  const last = new Date(end + 'T00:00:00Z');
  while (cursor <= last) {
    results.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return results;
}

function toLocalDay(timestamp, timeZone) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(new Date(timestamp));
}

function compareDayStrings(a, b) {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}

function roundToTwo(value) {
  return Math.round(value * 100) / 100;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function applyDailyCaps(timeline, caps) {
  for (const entry of timeline) {
    const capValue = caps[entry.date];
    if (typeof capValue !== 'number' || !Number.isFinite(capValue) || capValue < 0) {
      continue;
    }
    const flightIds = Object.keys(entry.flights);
    const activeIds = flightIds.filter(
      (id) => entry.flights[id].status === 'active' && entry.flights[id].budget > 0
    );
    if (activeIds.length === 0) {
      continue;
    }
    const totalActive = activeIds.reduce(
      (sum, id) => sum + Number(entry.flights[id].budget || 0),
      0
    );
    if (totalActive <= capValue + 1e-9) {
      // still enforce two decimal precision
      for (const id of activeIds) {
        entry.flights[id].budget = roundToTwo(entry.flights[id].budget);
      }
      continue;
    }

    let remaining = capValue;
    for (let i = 0; i < activeIds.length; i += 1) {
      const id = activeIds[i];
      const original = Number(entry.flights[id].budget || 0);
      let adjusted;
      if (i === activeIds.length - 1) {
        adjusted = roundToTwo(remaining);
      } else {
        adjusted = roundToTwo((original / totalActive) * capValue);
        remaining = roundToTwo(remaining - adjusted);
      }
      entry.flights[id].budget = adjusted < 0 ? 0 : adjusted;
    }
  }
}

module.exports = { computeTimeline };
`;

function writeTarget(targetPath) {
  mkdirSync(targetPath, { recursive: true });
}

const localTarget = resolve(scriptDir, 'campaign');
writeTarget(localTarget);
writeFileSync(resolve(localTarget, 'aggregator.js'), code);

const appTargetDir = resolve('/app/campaign');
try {
  writeTarget(appTargetDir);
  writeFileSync(resolve(appTargetDir, 'aggregator.js'), code);
} catch (err) {
  if (err.code !== 'ENOENT' && err.code !== 'EACCES') {
    throw err;
  }
}
NODE
*** End Patch
