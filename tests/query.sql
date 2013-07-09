USE `sphinxse-test`;

SELECT 		SQL_NO_CACHE name
FROM		location loc
INNER JOIN	`sphinxse-test` sphx ON sphx.id = loc.id
WHERE		sphx.query = 'chile;index=location;mode=extended;ranker=sph04'
