import { universeFixture } from "./cruds-fixture.js";

export const CRUDS_CONTRACT_VERSION = "cruds-e09.v1";

export function validateUniverse(payload) {
  if (!payload || payload.contractVersion !== CRUDS_CONTRACT_VERSION) throw new Error("Unsupported CRUDS contract version");
  for (const key of ["archetypes", "creators", "works", "opportunities", "research", "intelligence"]) {
    if (!Array.isArray(payload[key])) throw new Error(`Missing CRUDS collection: ${key}`);
  }
  for (const epic of ["e01", "e02", "e03", "e04", "e05", "e06", "e07", "e08"]) {
    if (!Array.isArray(payload.contractCoverage?.[epic]) || payload.contractCoverage[epic].length === 0) throw new Error(`Missing backend coverage: ${epic}`);
  }
  const archetypeCodes = new Set(payload.archetypes.map((item) => item.code));
  for (const expected of ["artist", "thinker", "adventurer", "maker", "producer", "dreamer"]) {
    if (!archetypeCodes.has(expected)) throw new Error(`Missing canonical archetype: ${expected}`);
  }
  return payload;
}

export async function loadUniverse() {
  const endpoint = import.meta.env.VITE_CRUDS_API_URL;
  if (!endpoint) return validateUniverse(universeFixture);
  const response = await fetch(`${endpoint.replace(/\/$/, "")}/universe`, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new Error(`CRUDS API returned ${response.status}`);
  return validateUniverse(await response.json());
}
