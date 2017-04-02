
/*Общая инфа*/

SELECT
   relname as "Таблица",
   pg_size_pretty(pg_total_relation_size(relid)) As "Общий размер",
   pg_size_pretty(pg_total_relation_size(relid)-pg_relation_size(relid)) as "Индексы, VM, FSM"
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

/*1*/
SELECT 
	ROUND(avg) AS "срд. знач. марш./авт." 
FROM (
	SELECT 
		AVG(count) 
	from (
		SELECT
		  COUNT(*) 
		FROM 
			tracks AS t LEFT JOIN cars AS c ON t.car_id = c.id 
		WHERE
			user_id = 1 
		GROUP BY c.id
	 ) AS cars
) AS cars_grouped;

SELECT 
	ROUND(avg)  AS "срд. знач. лок./марш." 
FROM (
	SELECT
		AVG(count) 
	FROM (
		SELECT 
			COUNT(l.id) 
		FROM locations l LEFT JOIN tracks t ON t.id = l.track_id 
		WHERE 
			t.car_id IN (
				SELECT 
					c.id 
				FROM 
					cars AS c 
				WHERE c.user_id = 1
			) 
		GROUP BY t.id
	) AS tracks
) AS tracks_grouped;



/*2*/
 WITH x AS (
   SELECT count(*)                AS ct
         ,sum(length(t::text))    AS txt_len  -- length in characters
         ,'locations'::regclass AS tbl
   FROM   locations t
   )
   , y AS (
   SELECT ARRAY [
             pg_relation_size(tbl) 
             ,pg_relation_size(tbl, 'vm')
             ,pg_relation_size(tbl, 'fsm')
             ,pg_table_size(tbl)
             ,pg_indexes_size(tbl)
             ,pg_total_relation_size(tbl)
             ,txt_len
           ] AS val
          ,ARRAY [
              'Общий размер отношения'
             ,'Карта видимости'
             ,'Размер свобоного пространства'
             ,'Размер таблицы, включая TOAST'
             ,'Размер индексов'
             ,'Общий размер, включая TOAST и индексы'
             ,'Кол-во используемых строк в текстовом представлении'
           ] AS name
    FROM   x
    )
 SELECT unnest(name)                AS "'Параметр'"
       ,unnest(val)                 AS "В байтах"
       ,pg_size_pretty(unnest(val)) AS "В удобночитаемом виде"
       ,unnest(val) / ct            AS "Байт на строку"
 FROM   x,y
 UNION  ALL
 SELECT '----------'::text, NULL::int8, '----'::text, NULL::int8
 UNION  ALL
 SELECT 'Число строк'::text, ct, 
 	NULL::text, NULL::bigint FROM x
 UNION  ALL
 SELECT 'Число действующих кортежей'::text, pg_stat_get_live_tuples(tbl), 
 		NULL::text, NULL::bigint FROM x
 UNION  ALL 
 	SELECT 'Число недействующих кортежей'::text, pg_stat_get_dead_tuples(tbl), NULL::text, NULL::bigint FROM x;


/*3*/
SELECT 
  relname, 
  seq_scan-idx_scan AS too_much_seq, 
  case when seq_scan-idx_scan>0 THEN 'Missing Index?' ELSE 'OK' END, 
  pg_relation_size(relid::regclass) AS rel_size, 
  seq_scan, 
  idx_scan 
FROM 
  pg_stat_all_tables
WHERE 
  schemaname='public' AND 
  pg_relation_size(relid::regclass)>25000 
ORDER BY too_much_seq DESC;

/*3.5*/
 SELECT
  i.indexname AS "Индекс",
  i.num_rows AS "Число кортежей",
  i.table_size AS "Размер таблицы",
  i.index_size AS "Размер индекса",
  i.unique AS "Уникальность",
  i.number_of_scans AS "Число использований",
  i.tuples_read AS "Прочитано, с помощью индекса",
  i.tuples_fetched AS "Выбрано, с помощью индекса"
FROM (
  SELECT
      t.tablename,
      indexname,
      c.reltuples AS num_rows,
      pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
      pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
      CASE WHEN indisunique THEN 'Y'
         ELSE 'N'
      END AS UNIQUE,
      idx_scan AS number_of_scans,
      idx_tup_read AS tuples_read,
      idx_tup_fetch AS tuples_fetched
  FROM pg_tables t
  LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
  LEFT OUTER JOIN
      ( SELECT c.relname AS ctablename, 
        ipg.relname AS indexname, 
        x.indnatts AS number_of_columns, 
        idx_scan,
        idx_tup_read, 
        idx_tup_fetch,
        indexrelname, 
        indisunique 
       FROM pg_index x
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_class ipg ON ipg.oid = x.indexrelid
       JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid )
      AS foo
      ON t.tablename = foo.ctablename
  WHERE t.schemaname='public' AND t.tablename = 'locations'
  ORDER BY number_of_scans DESC, 1 ASC, 2 ASC 
) AS i;

/*4*/
 SELECT
  i.indexname AS "Индекс",
  i.tablename AS "Таблица",
  i.num_rows AS "Число кортежей",
  i.table_size AS "Размер таблицы",
  i.index_size AS "Размер индекса",
  i.unique AS "Уникальность",
  i.number_of_scans AS "Число использований",
  i.tuples_read AS "Прочитано, с помощью индекса",
  i.tuples_fetched AS "Выбрано, с помощью индекса"
FROM (
  SELECT
      t.tablename,
      indexname,
      c.reltuples AS num_rows,
      pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
      pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
      CASE WHEN indisunique THEN 'Y'
         ELSE 'N'
      END AS UNIQUE,
      idx_scan AS number_of_scans,
      idx_tup_read AS tuples_read,
      idx_tup_fetch AS tuples_fetched
  FROM pg_tables t
  LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
  LEFT OUTER JOIN
      ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_class ipg ON ipg.oid = x.indexrelid
       JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid )
      AS foo
      ON t.tablename = foo.ctablename
  WHERE t.schemaname='public' AND c.reltuples > 0
  ORDER BY number_of_scans DESC, 1 ASC, 2 ASC 
) AS i;

/*4*/
 SELECT
  i.indexname AS "Индекс",
  i.tablename AS "Таблица",
  i.num_rows AS "Число кортежей",
  i.table_size AS "Размер таблицы",
  i.index_size AS "Размер индекса",
  i.unique AS "Уникальность",
  i.number_of_scans AS "Число использований",
  i.tuples_read AS "Прочитано, с помощью индекса",
  i.tuples_fetched AS "Выбрано, с помощью индекса"
FROM (
  SELECT
      t.tablename,
      indexname,
      c.reltuples AS num_rows,
      pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
      pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
      CASE WHEN indisunique THEN 'Y'
         ELSE 'N'
      END AS UNIQUE,
      idx_scan AS number_of_scans,
      idx_tup_read AS tuples_read,
      idx_tup_fetch AS tuples_fetched
  FROM pg_tables t
  LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
  LEFT OUTER JOIN
      ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns, idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
       JOIN pg_class c ON c.oid = x.indrelid
       JOIN pg_class ipg ON ipg.oid = x.indexrelid
       JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid )
      AS foo
      ON t.tablename = foo.ctablename
  WHERE t.schemaname='public' AND c.reltuples > 0
  ORDER BY number_of_scans DESC, 1 ASC, 2 ASC 
) AS i;

/* 5 */
  EXPLAIN (ANALYZE) SELECT 
    MAX("locations"."distance") AS maximum_distance, 
    "locations"."track_id" AS locations_track_id 
  FROM 
    "locations" 
  WHERE 
    "locations"."state" IN ('TrackLocation') AND
    "locations"."track_id" IN (
      SELECT 
        id 
      FROM 
        tracks 
      WHERE 
        car_id = 1
    ) 
  GROUP BY "locations"."track_id";

  /* 7 */
  EXPLAIN (ANALYZE) SELECT 
    MAX("locations"."distance") AS maximum_distance, 
    "locations"."track_id" AS locations_track_id 
  FROM 
    "locations" 
  WHERE 
    "locations"."track_id" IN (
      SELECT 
        id 
      FROM 
        tracks 
      WHERE 
        car_id = 1
    ) 
  GROUP BY "locations"."track_id";