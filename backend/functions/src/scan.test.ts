import assert from "node:assert/strict";
import { test } from "node:test";

import { normalize, ScanSchema, userPrompt, validateRequest } from "./scan";

test("validateRequest accepts a plain base64 jpeg", () => {
  const r = validateRequest({ image: "aGVsbG8=", mediaType: "image/jpeg", hint: "dal" });
  assert.equal(r.mediaType, "image/jpeg");
  assert.equal(r.hint, "dal");
});

test("validateRequest rejects bad input", () => {
  assert.throws(() => validateRequest({}), /image is required/);
  assert.throws(() => validateRequest({ image: "data:image/png;base64,AAA", mediaType: "image/png" }), /base64/);
  assert.throws(() => validateRequest({ image: "AAAA", mediaType: "image/gif" }), /mediaType/);
  assert.throws(() => validateRequest({ image: "A".repeat(5_000_001), mediaType: "image/png" }), /too large/);
});

test("normalize clamps and rounds", () => {
  const scan = ScanSchema.parse({
    is_food: true,
    items: [
      {
        name: "  Dal  ",
        portion: "1 katori",
        grams: 151.6,
        kcal: -20,
        protein_g: 9.04,
        carbs_g: 1e9,
        fat_g: 3.33,
        fiber_g: 4,
        veg: "veg",
        confidence: "medium",
      },
    ],
    note: "",
  });
  const n = normalize(scan);
  assert.equal(n.items[0].name, "Dal");
  assert.equal(n.items[0].grams, 152);
  assert.equal(n.items[0].kcal, 0);
  assert.equal(n.items[0].protein_g, 9);
  assert.equal(n.items[0].carbs_g, 600);
  assert.equal(n.items[0].fat_g, 3.3);
});

test("non-food photos return no items", () => {
  const n = normalize({ is_food: false, items: [], note: "A cat." });
  assert.equal(n.is_food, false);
  assert.deepEqual(n.items, []);
});

test("hint is trimmed and bounded", () => {
  assert.equal(userPrompt("  "), "Estimate the nutrition of this meal.");
  assert.ok(userPrompt("x".repeat(500)).length < 260);
});
