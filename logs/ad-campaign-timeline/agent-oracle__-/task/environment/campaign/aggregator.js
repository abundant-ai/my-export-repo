function computeTimeline(config) {
  const { flights = [] } = config || {};
  const timeline = [];

  for (const flight of flights) {
    const start = new Date(flight.startDate);
    const end = new Date(flight.endDate);
    for (
      let cursor = new Date(start);
      cursor <= end;
      cursor.setUTCDate(cursor.getUTCDate() + 1)
    ) {
      const iso = cursor.toISOString().slice(0, 10);
      let bucket = timeline.find((entry) => entry.date === iso);
      if (!bucket) {
        bucket = { date: iso, flights: {} };
        timeline.push(bucket);
      }
      bucket.flights[flight.id] = {
        status: "active",
        budget: flight.baseBudget,
      };
    }
  }

  timeline.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  return timeline;
}

module.exports = { computeTimeline };
