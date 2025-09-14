/* 
 * Решение ad hoc задач
 * Автор: Кокорин Максим
*/

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
SELECT
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) WITHIN GROUP (
	ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM
	real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
d AS (
SELECT
	*,
	CASE
		WHEN city = 'Санкт-Петербург'
	THEN city
		ELSE 'Ленинградская область'
	END AS region,
	CASE
		WHEN days_exposition >= 1
			AND days_exposition <= 30
	THEN 'До месяца'
			WHEN days_exposition >= 31
			AND days_exposition <= 90
	THEN 'До квартала'
			WHEN days_exposition >= 91
			AND days_exposition <= 180
	THEN 'До полугода'
			WHEN days_exposition >= 181
			AND days_exposition <= 365
	THEN 'До года'
			ELSE 'Больше года'
		END AS PERIOD
	FROM
		real_estate.flats
	JOIN real_estate.advertisement a
			USING(id)
	JOIN real_estate.city c
			USING(city_id)
	WHERE
		id IN (
		SELECT
			*
		FROM
			filtered_id)
),
m AS (
SELECT
	region,
	PERIOD,
	COUNT(id) AS num_ads,
	(COUNT(id)::NUMERIC / SUM(COUNT(id)) OVER (PARTITION BY region) * 100)::NUMERIC(5,2) AS total_adv_share,
	ROUND(AVG(last_price::NUMERIC / total_area)::NUMERIC, 2) AS avg_cost_sq_meter,
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area,
	ROUND(AVG(rooms)::NUMERIC, 2) AS avg_rooms,
	ROUND(AVG(balcony)::NUMERIC, 2) AS avg_balcony
FROM
	d
WHERE type_id = 'F8EM'
GROUP BY
	region,
	PERIOD
ORDER BY
	region,
	PERIOD
)
SELECT
	*
FROM
	m




-- Задача 2: Сезонность объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
SELECT
	PERCENTILE_DISC(0.99) WITHIN GROUP (
ORDER BY
	total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
ORDER BY
	rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
ORDER BY
	balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
ORDER BY
	ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) WITHIN GROUP (
ORDER BY
	ceiling_height) AS ceiling_height_limit_l
FROM
	real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
d AS (
SELECT
	*,
	EXTRACT(month FROM first_day_exposition) AS first_month_exposition,
	EXTRACT(month FROM first_day_exposition + days_exposition::int) AS last_month_exposition
FROM
	real_estate.flats
JOIN real_estate.advertisement a
		USING(id)
WHERE
	id IN (
	SELECT
		*
	FROM
		filtered_id)),
count_public_tb AS (
SELECT
	first_month_exposition,
	CASE
		WHEN first_month_exposition IS NOT NULL THEN first_month_exposition
	END AS dt,
	COUNT(first_month_exposition) AS num_public,
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area_pb,
	ROUND(AVG(last_price / total_area)::NUMERIC, 2) AS avg_cost_sq_meter_pb
FROM
	d
JOIN real_estate."type" t USING(type_id)
WHERE type_id = 'F8EM'
GROUP BY
	first_month_exposition,
	dt
),
count_remove_tb AS (
SELECT
	last_month_exposition,
	CASE
		WHEN last_month_exposition IS NOT NULL THEN last_month_exposition
	END AS dt,
	COUNT(last_month_exposition) AS num_remove,
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area_rm,
	ROUND(AVG(last_price / total_area)::NUMERIC, 2) AS avg_cost_sq_meter_rm
FROM
	d
JOIN real_estate."type" t USING(type_id)
WHERE type_id = 'F8EM' AND days_exposition IS NOT NULL
GROUP BY
	last_month_exposition,
	dt
)
SELECT
	dt,
	COALESCE(num_public, 0) AS num_public,
	COALESCE(num_remove, 0) AS num_remove,
	avg_total_area_pb,
	avg_total_area_rm,
	avg_cost_sq_meter_pb,
	avg_cost_sq_meter_rm
FROM
	count_remove_tb
FULL JOIN count_public_tb
		USING(dt)
ORDER BY
	dt


-- Задача 3: Анализ рынка недвижимости Ленобласти

-- Определим аномальные значения (выбросы) по значению перцентилей:
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
SELECT
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (
	ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) WITHIN GROUP (
	ORDER BY ceiling_height) AS ceiling_height_limit_l 
	FROM real_estate.flats),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL))
SELECT
	city, 
	type,
	COUNT(first_day_exposition) AS num_public,
	ROUND(COUNT(days_exposition)::NUMERIC / COUNT(*), 2) AS per_rm_ads,
	ROUND(AVG(last_price/total_area)::NUMERIC, 2) AS avg_cost_sq_meter,
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area,
	ROUND(AVG(days_exposition)::NUMERIC, 2) AS avg_days_esposition,
	ROUND(AVG(rooms)::NUMERIC, 2) AS avg_rooms,
	ROUND(AVG(balcony)::NUMERIC, 2) AS avg_balcony,
	ROUND(AVG(floor)::NUMERIC, 2) AS avg_floor
FROM
	real_estate.flats
JOIN real_estate.advertisement a
		USING(id)
JOIN real_estate.city c
		USING(city_id)
JOIN real_estate."type" t USING(type_id)
WHERE
	id IN (
	SELECT
		*
	FROM
		filtered_id)
	AND city_id <> '6X8I'
GROUP BY
	city, type
HAVING ROUND(AVG(days_exposition)::NUMERIC, 2) > 0
ORDER BY
	num_public DESC
LIMIT 15
