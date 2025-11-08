Repair the Node.js campaign timeline generator.

The script in campaign/aggregator.js must expand each flight day by day in the requested timezone while applying operational adjustments. Treat every adjustment timestamp using the provided Olson timezone so that an event influences the matching local calendar day. Apply state transitions cumulatively for each flight: pause or resume modifies all later days until another state change arrives and end_override shortens the schedule so that the specified day becomes the final active date.

Apply budget_override only on the target local day, using the last override recorded for that day, and report zero budget whenever a flight is paused. Respect the optional dailySpendCaps map by proportionally scaling the budgets of active flights so the capped total is not exceeded, while keeping paused flights at zero. Produce timeline entries for every calendar day beginning with the earliest flight start and ending with the latest effective end, listing every flight that is still active or paused on that day.

Emit a deterministic structure: for each day include every flight with an object describing its status (active or paused) and numeric budget, keep the flight identifiers sorted alphabetically, fall back to the base budget when no override is present, and leave the input payload untouched. Implement computeTimeline so that the provided Python tests pass.




