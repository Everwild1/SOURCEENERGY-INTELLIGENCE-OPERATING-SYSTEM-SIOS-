"""Verified top-level WITC cluster snapshot, reconciled 2026-08-20."""

TRADED_CLUSTERS = (
    (1, "Aerospace Vehicles and Defense"),
    (2, "Agricultural Inputs and Services"),
    (3, "Apparel"),
    (4, "Automotive"),
    (5, "Biopharmaceuticals"),
    (6, "Business Services"),
    (7, "Coal Mining"),
    (8, "Communications Equipment and Services"),
    (9, "Construction Products and Services"),
    (10, "Distribution and Electronic Commerce"),
    (11, "Downstream Chemical Products"),
    (12, "Downstream Metal Products"),
    (13, "Education and Knowledge Creation"),
    (14, "Electric Power Generation and Transmission"),
    (15, "Environmental Services"),
    (16, "Financial Services"),
    (17, "Fishing and Fishing Products"),
    (18, "Food Processing and Manufacturing"),
    (19, "Footwear"),
    (20, "Forestry"),
    (21, "Furniture"),
    (22, "Hospitality and Tourism"),
    (23, "Information Technology and Analytical Instruments"),
    (24, "Insurance Services"),
    (25, "Jewelry and Precious Metals"),
    (26, "Leather and Related Products"),
    (27, "Lighting and Electrical Equipment"),
    (28, "Livestock Processing"),
    (29, "Marketing, Design, and Publishing"),
    (30, "Medical Devices"),
    (31, "Metal Mining"),
    (32, "Metalworking Technology"),
    (33, "Music and Sound Recording"),
    (34, "Nonmetal Mining"),
    (35, "Oil and Gas Production and Transportation"),
    (36, "Paper and Packaging"),
    (37, "Performing Arts"),
    (38, "Plastics"),
    (39, "Printing Services"),
    (40, "Production Technology and Heavy Machinery"),
    (41, "Recreational and Small Electric Goods"),
    (42, "Textile Manufacturing"),
    (43, "Tobacco"),
    (44, "Trailers, Motor Homes, and Appliances"),
    (45, "Transportation and Logistics"),
    (46, "Upstream Chemical Products"),
    (47, "Upstream Metal Manufacturing"),
    (48, "Video Production and Distribution"),
    (49, "Vulcanized and Fired Materials"),
    (50, "Water Transportation"),
    (51, "Wood Products"),
)

LOCAL_CLUSTERS = (
    (101, "Local Food and Beverage Processing and Distribution"),
    (102, "Local Personal Services (Non-Medical)"),
    (103, "Local Health Services"),
    (104, "Local Utilities"),
    (105, "Local Logistical Services"),
    (106, "Local Household Goods and Services"),
    (107, "Local Financial Services"),
    (108, "Local Motor Vehicle Products and Services"),
    (109, "Local Retailing of Clothing and General Merchandise"),
    (110, "Local Entertainment and Media"),
    (111, "Local Hospitality Establishments"),
    (112, "Local Commercial Services"),
    (113, "Local Education and Training"),
    (114, "Local Community and Civic Organizations"),
    (115, "Local Real Estate, Construction, and Development"),
    (116, "Local Industrial Products and Services"),
)


def validate_verified_snapshot() -> None:
    traded_numbers = tuple(number for number, _ in TRADED_CLUSTERS)
    local_numbers = tuple(number for number, _ in LOCAL_CLUSTERS)
    if traded_numbers != tuple(range(1, 52)):
        raise ValueError("verified traded snapshot numbering drift")
    if local_numbers != tuple(range(101, 117)):
        raise ValueError("verified local snapshot numbering drift")
    all_names = [name for _, name in (*TRADED_CLUSTERS, *LOCAL_CLUSTERS)]
    if len(all_names) != len(set(all_names)):
        raise ValueError("verified top-level cluster names must be unique")
