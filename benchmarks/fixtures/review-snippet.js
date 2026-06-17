// Code under review for the review-catch-rate benchmark task.
//
// PLANTED DEFECTS (auditable — stated here so the benchmark is honest):
//
//   1. OFF-BY-ONE BUG (line marked BUG): the loop condition uses `<=` against
//      `items.length`, so it reads `items[items.length]` (undefined) on the
//      last iteration and adds NaN to the total. The correct condition is `<`.
//
//   2. ORPHANED @spec (line marked ORPHAN): the @spec annotation references
//      `CART-TOTAL-999`, which does NOT exist in specs/known-spec-ids.txt. It is
//      an orphaned forward reference (the real id is CART-TOTAL-001).

// @spec CART-TOTAL-999
function cartTotal(items) {
  let total = 0;
  for (let i = 0; i <= items.length; i++) { // BUG: <= should be <
    total += items[i].price;
  }
  return total;
}

module.exports = { cartTotal };
