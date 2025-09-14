-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
	COUNT(u.id) AS total_users, --посчитаем общее количество пользователей
	(
	SELECT
		COUNT(id) --посчитаем количество платящих игроков
	FROM
		fantasy.users
	WHERE
		payer = 1) AS pay_users,
	ROUND((SELECT COUNT(id) FROM fantasy.users WHERE payer = 1)::NUMERIC / COUNT(id), 2) AS per_pay_from_total
FROM
	fantasy.users u;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH table_count_user AS (
SELECT
		race,
		payer,
	COUNT(u.id) AS count_users
FROM
		fantasy.users u
JOIN fantasy.race r
		USING(race_id)
GROUP BY
	race, payer) --посчитаем кол-во игроков в разрезе каждой расы
SELECT
	race,
	SUM(count_users) FILTER(WHERE payer = 1) AS pay_users,
	SUM(count_users) FILTER(WHERE payer IN (0, 1)) AS reg_users,
	ROUND(SUM(count_users) FILTER(WHERE payer = 1)::NUMERIC / SUM(count_users) FILTER(WHERE payer IN (0, 1)), 2) AS per_pay_from_total
FROM
	table_count_user
GROUP BY race
ORDER BY per_pay_from_total DESC, pay_users DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
	'С учетом нулевых покупок' AS category,
	COUNT(transaction_id) AS count_buy,
	SUM(amount) AS sm_amount,
	MIN(amount) AS mn_amount,
	MAX(amount) AS mx_amount,
	ROUND(AVG(amount)::numeric, 2) AS avg_amount,
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::numeric, 2) AS median,
	ROUND(STDDEV(amount)::NUMERIC, 2) AS stand_deviation
FROM
	fantasy.events e
UNION
SELECT
	'Без учета нулевых покупок',
	COUNT(transaction_id) AS count_buy,
	SUM(amount) AS sm_amount,
	MIN(amount) AS mn_amount, --минимальная покупка около 0
	MAX(amount) AS mx_amount, --максимальная больше 486 тысяч
	ROUND(AVG(amount)::numeric, 2) AS avg_amount, --среднее значение стоимости — 526,06, что говорит о большом размахе стоимости покупок при сравнении с медианой
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::numeric, 2) AS median, --половина покупок со стоимостью меньше 74,86
	ROUND(STDDEV(amount)::NUMERIC, 2) AS stand_deviation --стандартное отклонение велико, что так же говорит о большой степени разброса
FROM
	fantasy.events e
WHERE
	amount > 0

-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(*) FILTER (WHERE amount = 0) AS zero_amounts, -- количество нулевых покупок
    COUNT(*) AS total_amounts, -- общее количество покупок
    COUNT(*) FILTER (WHERE amount = 0)::REAL / COUNT(*) AS zero_share -- доля нулевых покупок
FROM fantasy.events; 

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH table_count_buy AS (
SELECT
	id,
	payer,
	COUNT(transaction_id) AS count_buy,
	SUM(amount) AS sm_amount
FROM
	fantasy.events e
JOIN fantasy.users u
		USING(id)
WHERE amount > 0
GROUP BY
	id,
	payer
) --посчитаем количество и сумму покупок по каждому игроку
SELECT
	'Неплатящие игроки' AS category_users,
	COUNT(id) AS total_user,
	ROUND(AVG(count_buy)::NUMERIC, 2) AS avg_count_buy,
	ROUND(AVG(sm_amount)::NUMERIC, 2) AS avg_sm_amount
FROM
	table_count_buy
WHERE
	payer = 0
UNION
SELECT
	'Платящие игроки' AS category_users,
	COUNT(id),
	ROUND(AVG(count_buy)::NUMERIC, 2),
	ROUND(AVG(sm_amount)::NUMERIC, 2)
FROM
	table_count_buy
WHERE
	payer = 1;

-- 2.4: Популярные эпические предметы:
SELECT
	game_items,
	COUNT(transaction_id) AS count_buy,
	ROUND(COUNT(transaction_id)::NUMERIC / (SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount > 0), 6) AS per_buy_from_total_buy,
	ROUND(COUNT(DISTINCT id)::NUMERIC / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0), 6) AS per_user_from_total_user
FROM
	fantasy.items i
LEFT JOIN fantasy.events e
		USING(item_code)
WHERE amount > 0
GROUP BY
	game_items
ORDER BY
	count_buy DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH table_count_pay_user AS (
SELECT
		race,
	COUNT(DISTINCT id) AS pay_users
FROM
		fantasy.users
JOIN fantasy.race r USING(race_id)
JOIN fantasy.events e USING(id)	
WHERE
		payer = 1 AND amount > 0
GROUP BY
	race), --количество платящих игроков по каждой расе
table_count_user AS (
SELECT
		race,
	COUNT(DISTINCT id) AS events_users
FROM
		fantasy.users
JOIN fantasy.race r USING(race_id)
JOIN fantasy.events e USING(id)	
WHERE amount > 0
GROUP BY
	race),
table_count_reg_user AS (
SELECT
	race,
	   COUNT(u.id) AS reg_users
FROM
	fantasy.users u
JOIN fantasy.race r
		USING(race_id)
GROUP BY
	race), --общее количество игроков, относящихся к конкретной расе
table_avg_buy AS (
SELECT
	race,
	ROUND(AVG(count_buy), 2) AS avg_count_buy,
	ROUND(AVG(sm_amount)::NUMERIC, 2) AS avg_sm_amount
FROM
	(
	SELECT
		id,
		race,
		COUNT(transaction_id) AS count_buy,
		SUM(amount) AS sm_amount
	FROM
		fantasy.events e
	JOIN fantasy.users
			USING(id)
	JOIN fantasy.race
			USING(race_id)
	WHERE amount > 0
	GROUP BY
		id,
		race) AS table_total_buy 
GROUP BY
	race
), --расчет средних показателей по количеству и сумме покупок на одного игрока
table_avg_amount AS (
SELECT
	race,
	ROUND(AVG(amount)::NUMERIC, 2) AS avg_amount
FROM
	fantasy.events e
JOIN fantasy.users
		USING(id)
JOIN fantasy.race
		USING(race_id)
WHERE amount > 0
GROUP BY
	race
) --расчет средней стоимости одной покупки в зависимости от расы
	SELECT
	race,
	events_users,
	pay_users,
	reg_users,
	ROUND(pay_users::NUMERIC / events_users, 2) AS per_pay_from_events,
	avg_count_buy,
	avg_amount,
	avg_sm_amount
FROM
	table_count_reg_user
JOIN table_count_pay_user
		USING(race)
JOIN table_avg_buy
		USING(race)
JOIN table_avg_amount
		USING(race)
JOIN table_count_user
		USING(race)
ORDER BY
	pay_users DESC,
	reg_users DESC;

-- Задача 2: Частота покупок
WITH table_count_buy AS (
SELECT
	id,
	payer,
	COUNT(transaction_id) AS count_buy
FROM
	fantasy.events
	JOIN fantasy.users u USING(id)
WHERE
	amount > 0
GROUP BY
	id, payer
HAVING
	COUNT(transaction_id) >= 25
ORDER BY
	COUNT(transaction_id) DESC),
table_avg_interval_days AS
(
SELECT
	id,
	ROUND(AVG(interval_days)) AS avg_interval_days
FROM
	(
	SELECT
		id,
		date::date,
		LAG(date::date) OVER(PARTITION BY id ORDER BY date::date),
		date::date - LAG(date::date) OVER(PARTITION BY id ORDER BY date::date) AS interval_days
	FROM
		fantasy.events
	WHERE
		amount > 0) AS d
GROUP BY
	id),
table_nt_group AS (
SELECT
	*,
	NTILE(3) OVER(ORDER BY count_buy DESC) AS nt_group
FROM
	table_avg_interval_days
JOIN table_count_buy
		USING(id)),
table_group AS (
SELECT
	*,
	CASE
			WHEN nt_group = 1
				THEN 'высокая частота'
		WHEN nt_group = 2
				THEN 'умеренная частота'
		WHEN nt_group = 3
				THEN 'низкая частота'
	END AS group_nt
FROM
	table_nt_group)
SELECT
	group_nt,
	SUM(payer) AS payer_user,
	COUNT(id) AS total_user,
	ROUND(SUM(payer)::NUMERIC / COUNT(id), 2) AS per_payer_from_total,
	ROUND(AVG(count_buy)) AS avg_count_buy,
	ROUND(AVG(avg_interval_days)) AS avg_interval_days
FROM
	table_group
GROUP BY
	group_nt;
