update ecology.ssr_canonicalization_requirements
set requirement_description='Assign an SSR Z-index in the permitted Earth operational range -4000..7000 under SSR-Z-EGM96-3M-V1.',
    evidence_rule='Z must be deterministically derived from authoritative EGM96-relative elevation using 3 m quantization; do not infer from facility type, local floor numbering, terrain class, or W3W alone.'
where requirement_code='SSR-CAN-03';
