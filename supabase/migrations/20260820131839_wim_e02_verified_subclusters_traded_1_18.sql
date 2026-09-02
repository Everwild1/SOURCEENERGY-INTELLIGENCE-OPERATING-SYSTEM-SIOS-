insert into wim.economic_subclusters (cluster_id, source_subcluster_number, canonical_code, name, source_url, status)
select c.id, v.sub_no, c.canonical_code || '-S' || lpad(v.sub_no::text,2,'0'), v.name, 'https://wimexchange.com/the-west-indies-trading-company/', 'active'
from (values
(1,1,'Aircraft'),(1,2,'Missiles and Space Vehicles'),(1,3,'Search and Navigation Equipment'),
(2,1,'Agricultural Services'),(2,2,'Farm Management and Labor Services'),(2,3,'Fertilizers'),
(3,1,'Accessories and Specialty Apparel'),(3,2,'Men’s Clothing'),(3,3,'Women’s Clothing'),(3,4,'Apparel Contractors'),
(4,1,'Automotive Parts'),(4,2,'Gasoline Engines and Engine Parts'),(4,3,'Motor Vehicles'),(4,4,'Small Vehicles'),(4,5,'Military Vehicles and Tanks'),(4,6,'Metal Mills and Foundries'),
(5,1,'Biopharmaceutical Products'),(5,2,'Biological Products'),(5,3,'Diagnostic Substances'),
(6,1,'Corporate Headquarters'),(6,2,'Consulting Services'),(6,3,'Business Support Services'),(6,4,'Computer Services'),(6,5,'Employment Placement Services'),(6,6,'Engineering Services'),(6,7,'Architectural and Drafting Services'),(6,8,'Ground Passenger Transportation'),
(7,1,'Coal Mining'),
(8,1,'Communications Services'),(8,2,'Communications Equipment'),(8,3,'Communications Equipment Components'),
(9,1,'Construction'),(9,2,'Water, Sewage, and Other Systems'),(9,3,'Construction Products'),(9,4,'Construction Components'),(9,5,'Construction Materials'),
(10,1,'Warehousing and Storage'),(10,2,'Electronic and Catalog Shopping'),(10,3,'Wholesale Trade Agents and Brokers'),(10,4,'Support Services'),(10,5,'Wholesale of Apparel and Accessories'),(10,6,'Wholesale of Books, Periodicals, and Newspapers'),(10,7,'Wholesale of Chemical and Allied Products'),(10,8,'Wholesale of Drugs and Druggists’ Sundries'),(10,9,'Wholesale of Farm Products and Supplies'),(10,10,'Wholesale of Food Products'),(10,11,'Wholesale of Furniture and Home Furnishing'),(10,12,'Wholesale of Jewelry, Watches, Precious Stones, and Precious Metals'),(10,13,'Wholesale of Paper and Paper Products'),(10,14,'Wholesale of Sporting and Recreational Goods and Supplies'),(10,15,'Wholesale of Toy and Hobby Goods and Supplies'),(10,16,'Wholesale of Other Merchandise'),(10,17,'Wholesale of Farm and Garden Machinery and Equipment'),(10,18,'Wholesale of Construction and Mining Machinery and Equipment'),(10,19,'Wholesale of Industrial Machinery, Equipment, and Supplies'),(10,20,'Wholesale of Service Establishment Equipment, and Supplies'),(10,21,'Wholesale of Transportation Equipment and Supplies (except Motor Vehicles)'),(10,22,'Wholesale of Professional and Commercial Equipment and Supplies'),(10,23,'Wholesale of Electrical and Electronic Goods'),(10,24,'Wholesale of Metals and Minerals (except Petroleum)'),(10,25,'Wholesale of Petroleum and Petroleum Products'),(10,26,'Rental and Leasing'),
(11,1,'Personal Care and Cleaning Products'),(11,2,'Processed Chemical Products'),(11,3,'Dyes, Pigments and Coating'),(11,4,'Explosives'),(11,5,'Lubricating Oils and Greases'),
(12,1,'Metal Products'),(12,2,'Ammunition'),(12,3,'Fabricated Metal Structures'),(12,4,'Metal Containers'),
(13,1,'Training Programs'),(13,2,'Colleges, Universities, and Professional Schools'),(13,3,'Educational Support Services'),(13,4,'Research Organizations'),(13,5,'Professional Organizations'),
(14,1,'Fossil Fuel Electric Power'),(14,2,'Alternative Electric Power'),(14,3,'Electric Power Transmission'),
(15,1,'Waste Collection'),(15,2,'Waste Processing'),(15,3,'Other Waste Management Services'),
(16,1,'Financial Investment Activities'),(16,2,'Credit Intermediation'),(16,3,'Credit Bureaus'),(16,4,'Monetary Authorities – Central Bank'),(16,5,'Securities Brokers, Dealers, and Exchanges'),
(17,1,'Fishing and Fishing Products'),
(18,1,'Specialty Foods and Ingredients'),(18,2,'Baked Goods'),(18,3,'Candy and Chocolate'),(18,4,'Coffee and Tea'),(18,5,'Packaged Fruit and Vegetables'),(18,6,'Dairy Products'),(18,7,'Animal Foods'),(18,8,'Soft Drinks and Ice'),(18,9,'Malt Beverages'),(18,10,'Distilleries'),(18,11,'Wineries'),(18,12,'Milling and Refining of Cereals and Oilseeds'),(18,13,'Milling and Refining of Sugar'),(18,14,'Farm Wholesalers'),(18,15,'Glass Containers')
) as v(cluster_no,sub_no,name)
join wim.economic_clusters c on c.source_cluster_number=v.cluster_no and c.cluster_scope='traded'
on conflict (canonical_code) do nothing;
