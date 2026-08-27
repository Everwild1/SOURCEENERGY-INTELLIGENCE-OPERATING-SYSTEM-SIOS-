import assert from "node:assert/strict";
import test from "node:test";
import { readFile } from "node:fs/promises";
import { validateUniverse } from "../src/data/cruds-client.js";
import { universeFixture } from "../src/data/cruds-fixture.js";

test("E09 payload contains the six canonical archetypes", () => {
  const result = validateUniverse(universeFixture);
  assert.deepEqual(result.archetypes.map((item) => item.code), ["artist", "thinker", "adventurer", "maker", "producer", "dreamer"]);
});

test("E09 payload spans the E01-E08 public collections", () => {
  const result = validateUniverse(universeFixture);
  for (const key of ["creators", "works", "opportunities", "research", "intelligence"]) assert.ok(result[key].length > 0);
  assert.deepEqual(Object.keys(result.contractCoverage), ["e01", "e02", "e03", "e04", "e05", "e06", "e07", "e08"]);
});

test("E09 rejects incompatible payload versions", () => {
  assert.throws(() => validateUniverse({ ...universeFixture, contractVersion: "cruds-unknown" }), /Unsupported/);
});

test("E09 renders the cross-context authority boundaries", async () => {
  const source = await readFile(new URL("../src/App.jsx", import.meta.url), "utf8");
  for (const statement of [
    "Evidence requests and authority confirmations remain references to the approved verifier",
    "WIM Exchange while WIM retains workflow and transaction authority",
    "External rails retain finality and ledger authority",
    "does not create a contract or transaction",
    "distinct from authoritative transaction or settlement state",
  ]) assert.match(source, new RegExp(statement));
});
