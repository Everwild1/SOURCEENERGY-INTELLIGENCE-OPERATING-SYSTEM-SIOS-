# Global Supply Chain Command Layer

Status: Implementation baseline  
Epic: #135

## Mission

The Global Supply Chain (GSC) Command Layer governs cross-domain physical commerce across SourceEnergy Global. It does not replace WIM Exchange, Robert Logix, the Spatial Registry, SETC, or settlement systems. It orchestrates them through explicit authority boundaries.

## Canonical flow

Source / Producer → Qualification → Procurement → WIM Market Access → Contract → Finance / Settlement → Multimodal Logistics → Customs / Compliance → Storage → Distribution → Delivery → Chain of Custody → Wealth Ecology Intelligence

## Authority map

| Domain | Authority |
|---|---|
| Market discovery, products/services, opportunities, commercial transactions | `wim` |
| Orders, contracts, carriers, corridors, rail, drone, shipments, customs, tracking, delivery | `rgl` |
| Spatial identity and reconciliation | `public.ssr_spatial_registry`, `rgl.spatial_registry_links` |
| Cross-domain portfolio and orchestration | `gsc` |
| Provenance / blockchain evidence | SETC boundary |
| Settlement | WIM settlement requests and separately governed Source Coin/banking rails |

## GSC workstreams

1. GSC-01 Commodity Registry
2. GSC-02 Organization / Supply Node Registry
3. GSC-03 Global Corridor Portfolio
4. GSC-04 Multimodal Logistics Integration
5. GSC-05 Energy & Diesel Distribution
6. GSC-06 Materials / Perryville Integration
7. GSC-07 WIM Exchange Bridge
8. GSC-08 Spatial Registry Bridge
9. GSC-09 SETC Provenance Boundary
10. GSC-10 Settlement Boundary
11. GSC-11 Compliance & Trade Controls
12. GSC-12 Supply Chain / Wealth Ecology Intelligence

## Geographic mandate

Global coverage with dedicated focus on North America, Caribbean Basin, and Africa, connected through Diaspora trade and infrastructure corridors.

## Commodity baseline

Energy: ULSD/diesel, Jet A-1, AGO, gasoline, LPG, LNG, crude, base oils, bitumen.

Materials: lithium and battery inputs, graphite/graphene, metals, industrial minerals and strategic manufacturing materials.

Agriculture: urea/fertilizer, food and strategic agricultural commodities.

Infrastructure: water-system components, EPC equipment and resilient-infrastructure materials.

## Multimodal execution

The physical network includes maritime, ports, air cargo, trucking, rail networks and terminals, warehouses/logistics hubs, drone delivery zones/fleets/missions, and last-mile delivery.

## Integration rule

GSC stores portfolio/orchestration metadata and references canonical WIM/RGL/SSR records. It must not create competing transaction, shipment, organization, or spatial authorities.

## Perryville rule

Perryville is designated as a candidate materials node. Production activation requires authoritative identity reconciliation to an existing or newly qualified organization/facility record before operational linkage.

## Security baseline

All GSC tables in exposed schemas must use RLS. Anonymous mutation is prohibited. Authorization must not rely on user-editable metadata. Service-role credentials must never be exposed to frontend clients.

## Delivery sequence

1. Schema and cross-domain reference contract.
2. Commodity and supply-node taxonomy.
3. Diesel distribution program.
4. Corridor and multimodal portfolio integration.
5. WIM transaction / RGL shipment / spatial evidence traceability.
6. Compliance and settlement boundary integration.
7. Command-center frontend/API.
8. Intelligence and Wealth Ecology metrics.
