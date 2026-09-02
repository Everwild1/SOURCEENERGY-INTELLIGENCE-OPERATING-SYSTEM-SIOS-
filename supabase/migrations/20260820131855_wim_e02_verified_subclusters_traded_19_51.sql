insert into wim.economic_subclusters (cluster_id, source_subcluster_number, canonical_code, name, source_url, status)
select c.id, v.sub_no, c.canonical_code || '-S' || lpad(v.sub_no::text,2,'0'), v.name, 'https://wimexchange.com/the-west-indies-trading-company/', 'active'
from (values
(19,1,'Footwear'),(19,2,'Footwear Parts'),(20,1,'Forestry'),
(21,1,'Wood Household Furniture'),(21,2,'Non-Wood Household Furniture'),(21,3,'Office Furniture'),(21,4,'Institutional Furniture'),(21,5,'Furniture Wholesalers'),
(22,1,'Hotels and Motels'),(22,2,'Other Accommodations'),(22,3,'Recreational and Vacation Camps'),(22,4,'Restaurants'),(22,5,'Travel Agencies'),(22,6,'Tour Operators'),(22,7,'Gambling'),
(23,1,'Computers and Peripherals'),(23,2,'Office and Computing Machines'),(23,3,'Software Products'),(23,4,'Audio and Video Equipment'),(23,5,'Optical Instruments'),(23,6,'Navigational and Measurement Equipment'),(23,7,'Laboratory Instruments'),(23,8,'Electronic Components'),
(24,1,'Insurance Carriers'),(24,2,'Insurance Agencies and Brokerages'),(24,3,'Reinsurance Carriers'),
(25,1,'Jewelry and Precious Metals'),
(26,1,'Leather Products'),(26,2,'Leather and Hide Tanning'),(26,3,'Leather Wholesalers'),
(27,1,'Electric Lighting Equipment'),(27,2,'Small Electrical Appliances'),(27,3,'Electrical Equipment'),(27,4,'Electrical Equipment Components'),
(28,1,'Meat Processing'),(28,2,'Seafood Products'),
(29,1,'Marketing and Related Services'),(29,2,'Industrial Design Services'),(29,3,'Publishing'),(29,4,'Signs'),
(30,1,'Medical Devices'),(30,2,'Medical Equipment Wholesalers'),
(31,1,'Metal Mining'),
(32,1,'Metalworking Machinery'),(32,2,'Metalworking Machinery Parts'),(32,3,'Metalworking Services'),(32,4,'Process Equipment'),(32,5,'Process Equipment Components'),
(33,1,'Music and Sound Recording'),
(34,1,'Nonmetal Mining'),
(35,1,'Oil and Gas Production'),(35,2,'Oil and Gas Transportation'),(35,3,'Oil and Gas Machinery and Equipment'),(35,4,'Oil and Gas Services'),(35,5,'Oil and Gas Wholesalers'),(35,6,'Oil and Gas Pipelines'),
(36,1,'Paper Products'),(36,2,'Paper Mills'),(36,3,'Paperboard Containers'),
(37,1,'Performing Arts'),(37,2,'Independent Artists, Writers, and Performers'),
(38,1,'Plastics Products'),(38,2,'Plastics Materials and Resins'),
(39,1,'Printing Services'),(39,2,'Printing Equipment'),(39,3,'Printing Supplies'),(39,4,'Printing Machinery'),
(40,1,'Heavy Machinery'),(40,2,'Construction Machinery'),(40,3,'Agricultural Machinery'),(40,4,'Industrial Machinery'),(40,5,'Commercial and Service Industry Machinery'),(40,6,'Material Handling Equipment'),
(41,1,'Recreational Goods'),(41,2,'Small Electric Appliances'),(41,3,'Small Mechanical Appliances'),(41,4,'Sporting and Athletic Goods'),(41,5,'Toys and Games'),(41,6,'Recreational Boats'),
(42,1,'Textile Manufacturing'),(42,2,'Textile Mills'),(42,3,'Textile Product Mills'),(42,4,'Textile Wholesalers'),(42,5,'Carpet and Rug Mills'),(42,6,'Curtain and Linen Mills'),(42,7,'Other Textile Product Mills'),
(43,1,'Tobacco'),
(44,1,'Trailers'),(44,2,'Motor Homes'),(44,3,'Household Appliances'),
(45,1,'Air Transportation'),(45,2,'Rail Transportation'),(45,3,'Truck Transportation'),(45,4,'Support Activities for Transportation'),(45,5,'Couriers and Messengers'),
(46,1,'Basic Chemicals'),(46,2,'Petrochemicals'),(46,3,'Industrial Gases'),(46,4,'Fertilizers'),
(47,1,'Iron and Steel Mills'),(47,2,'Aluminum Production'),(47,3,'Nonferrous Metal Production'),(47,4,'Foundries'),
(48,1,'Video Production and Distribution'),
(49,1,'Glass Products'),(49,2,'Cement and Concrete Products'),(49,3,'Ceramics'),
(50,1,'Deep Sea, Coastal, and Great Lakes Water Transportation'),(50,2,'Inland Water Transportation'),(50,3,'Port and Harbor Operations'),
(51,1,'Sawmills and Wood Preservation'),(51,2,'Plywood and Engineered Wood Products'),(51,3,'Other Wood Products')
) as v(cluster_no,sub_no,name)
join wim.economic_clusters c on c.source_cluster_number=v.cluster_no and c.cluster_scope='traded'
on conflict (canonical_code) do nothing;
