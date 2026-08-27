-- Contract test for SSR deterministic spatial identity resolution.
BEGIN;

INSERT INTO anchor_tiles(anchor_tile_id,w3w_address,latitude,longitude,activation_date,vertical_datum,source_system,source_record_id)
VALUES('TEST-ANCHOR-001','///test.anchor.tile',0,0,NOW(),'EGM96','test_fixture','determinism-contract');

DO $$
DECLARE
  a spatial_cubes;
  b spatial_cubes;
BEGIN
  a := ssr_resolve_cube('TEST-ANCHOR-001', 0);
  b := ssr_resolve_cube('TEST-ANCHOR-001', 0);
  IF a.cube_uid <> b.cube_uid OR a.canonical_address <> b.canonical_address THEN
    RAISE EXCEPTION 'SSR determinism contract failed';
  END IF;
  IF a.canonical_address <> '///test.anchor.tile@Z+0000' THEN
    RAISE EXCEPTION 'Unexpected canonical address: %', a.canonical_address;
  END IF;
END $$;

ROLLBACK;
