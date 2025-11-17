--EDA on listings:

--1
select min(first_day_exposition) as min_date,
       max(first_day_exposition) as max_date
from real_estate.advertisement;

--2
SELECT 
    t.type AS type_name,
    COUNT(DISTINCT c.city_id) AS city_count,
    COUNT(a.id) AS ads_count
FROM real_estate.advertisement AS a
JOIN real_estate.flats AS f ON a.id = f.id
JOIN real_estate.city AS c ON f.city_id = c.city_id
JOIN real_estate.type AS t ON f.type_id = t.type_id
GROUP BY t.type
ORDER BY ads_count DESC;
-- Query results:
-- settlement type| number of settlements | number of listings
-- город                           | 43   | 20008
-- посёлок                         | 113  | 2092
-- деревня                         | 106  | 945
-- посёлок городского типа         | 30   | 363
-- городской посёлок               | 13   | 187
-- село                            | 9    | 32
-- посёлок при ж/д станции         | 6    | 15
-- садовое товарищество            | 4    | 4
-- коттеджный посёлок              | 3    | 3
-- садоводческое некоммерческое т-во | 1  | 1

--The majority of listings are concentrated in cities (around 20k), which makes sense — these are the most active markets.
-- Village settlements and villages also have a noticeable number of listings, but significantly fewer.
-- Small settlement types (garden partnerships, cottage settlements, etc.) are extremely rare.
-- Therefore, the main focus when analyzing the real estate market should be on cities and large settlements.


--3
SELECT
    MIN(days_exposition) AS min_days,
    MAX(days_exposition) AS max_days,
    ROUND(AVG(days_exposition::numeric), 2) AS avg_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_exposition) AS median_days
FROM real_estate.advertisement;
-- Query results:
-- min_days  |  max_days  |  avg_days  |  median_days
-- ---------- | ----------- | ---------- | -------------
-- 1.0        | 1580.0      | 180.75     | 95.0

--Minimum listing duration — 1 day.
-- Maximum — 1,580 days (about 4.3 years).
-- Average duration — 180.75 days, median — 95 days.
-- Distribution is skewed: most listings close within 3 months,
-- but a small share of very long listings significantly raises the average.

--4
SELECT 
    ROUND(
        COUNT(days_exposition)::numeric / COUNT(*) * 100, 
        2
    ) AS sold_percent
FROM real_estate.advertisement;
--86.55 percent of the real estate can be considered sold, the rest remain active

--5 Calculating the share of apartments in SPB
SELECT 
    ROUND(
        COUNT(f.id)::numeric / (SELECT COUNT(*) FROM real_estate.flats) * 100, 
        2
    ) AS spb_percent
FROM real_estate.flats f
JOIN real_estate.city c ON f.city_id = c.city_id
WHERE c.city = 'Санкт-Петербург';
--66.47 Ratio between listings in Saint Petersburg and Leningrad Oblast roughly 66 to 34, or about 2 to 1.

--6 Calculating the key statistical indicators for the values of the cost per square meter
WITH price_per_m2 AS (
    SELECT 
        (a.last_price::numeric / f.total_area::numeric) AS price_m2
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    WHERE a.last_price IS NOT NULL AND f.total_area IS NOT NULL
)
SELECT
    ROUND(MIN(price_m2), 2) AS min_price_per_m2,
    ROUND(MAX(price_m2), 2) AS max_price_per_m2,
    ROUND(AVG(price_m2), 2) AS avg_price_per_m2,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_m2::double precision) AS numeric), 2) AS median_price_per_m2
FROM price_per_m2;

-- Query results:
-- min_price_per_m2 | max_price_per_m2 | avg_price_per_m2 | median_price_per_m2
-- ---------------- | ---------------- | ---------------- | ------------------
-- 111.83           | 1907500.00       | 99432.25         | 95000.00

-- Conclusions:
-- Minimum price per square meter — 111.83 RUB
-- Maximum price per square meter — 1,907,500 RUB
-- Average price per square meter — 99,432.25 RUB
-- Median price per square meter — 95,000 RUB, indicating a skewed distribution: some expensive properties significantly raise the average.
-- For analyzing typical prices, it is better to focus on the median.

--7 Checking the data for correctness and calculate statistical indicators — minimum
--and maximum values, mean, median, and 99th percentile for the following
--quantitative data: total property area, number of rooms and balconies,
--ceiling height, floor.
 
SELECT
    ROUND(MIN(total_area)::numeric, 2) AS min_total_area,
    ROUND(MAX(total_area)::numeric, 2) AS max_total_area,
    ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area::double precision) AS numeric), 2) AS median_total_area,
    ROUND(CAST(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area::double precision) AS numeric), 2) AS perc99_total_area,
    ROUND(MIN(rooms)::numeric, 2) AS min_rooms,
    ROUND(MAX(rooms)::numeric, 2) AS max_rooms,
    ROUND(AVG(rooms)::numeric, 2) AS avg_rooms,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms::double precision) AS numeric), 2) AS median_rooms,
    ROUND(CAST(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rooms::double precision) AS numeric), 2) AS perc99_rooms,
    ROUND(MIN(balcony)::numeric, 2) AS min_balcony,
    ROUND(MAX(balcony)::numeric, 2) AS max_balcony,
    ROUND(AVG(balcony)::numeric, 2) AS avg_balcony,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony::double precision) AS numeric), 2) AS median_balcony,
    ROUND(CAST(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY balcony::double precision) AS numeric), 2) AS perc99_balcony,
    ROUND(MIN(ceiling_height)::numeric, 2) AS min_ceiling,
    ROUND(MAX(ceiling_height)::numeric, 2) AS max_ceiling,
    ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ceiling_height::double precision) AS numeric), 2) AS median_ceiling,
    ROUND(CAST(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height::double precision) AS numeric), 2) AS perc99_ceiling,
    ROUND(MIN(floor)::numeric, 2) AS min_floor,
    ROUND(MAX(floor)::numeric, 2) AS max_floor,
    ROUND(AVG(floor)::numeric, 2) AS avg_floor,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor::double precision) AS numeric), 2) AS median_floor,
    ROUND(CAST(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY floor::double precision) AS numeric), 2) AS perc99_floor
FROM real_estate.flats
WHERE total_area IS NOT NULL;
---- Stats  for total apartment area (sq. m):
-- min_total_area | max_total_area | avg_total_area | median_total_area | perc99_total_area
-- -------------- | -------------- | -------------- | ---------------- | ----------------
-- 12.00          | 900.00         | 60.33          | 52.00            | 197.56

-- Minimum area — 12 m², most likely studios or small apartment-units.
-- Maximum area — 900 m², clearly exceptional properties (possibly penthouses or luxury real estate).
-- Average area — 60.33 m², roughly corresponding to a standard two- or three-room apartment.
-- Median area — 52 m², slightly below the average, indicating the presence of smaller apartments and a distribution skewed toward larger units.
-- 99th percentile — 197.56 m²; this value represents the upper extreme for most listings and helps identify rare, very large apartments.
-- For analyzing typical properties, it’s better to focus on the median rather than the mean to avoid the influence of rare large apartments.


--Stats by number of rooms
-- min_rooms | max_rooms | avg_rooms | median_rooms | perc99_rooms
-- --------- | --------- | ---------- | ------------ | -------------
-- 0.00      | 19.00     | 2.07       | 2.00         | 5.00

-- Minimum number of rooms — 0, studio.
-- Maximum number of rooms — 19, these are clearly extreme cases, possibly large apartments or combined units.
-- Average — 2.07 rooms per apartment, slightly above the median due to rare large apartments.
-- Median — 2 rooms, reflecting the typical option for most apartments.
-- 99th percentile — 5 rooms, showing the upper limit for almost all apartments, excluding rare large units.
-- For analyzing the standard housing stock, it’s better to focus on the median to avoid distortion from rare large apartments.

-- Stats for the number of balconies:
-- min_balcony | max_balcony | avg_balcony | median_balcony | perc99_balcony
-- ----------- | ----------- | ----------- | -------------- | --------------
-- 0.00        | 5.00        | 1.15        | 1.00           | 5.00


-- Minimum number of balconies — 0, typical for most apartments without balconies or loggias.
-- Maximum number of balconies — 5, rare large apartments with multiple balconies.
-- Average — 1.15 balconies per apartment, slightly above the median, indicating some units with many balconies.
-- Median — 1 balcony, reflecting the typical option for most apartments.
-- 99th percentile — 5 balconies, showing the upper limit for almost all units, excluding rare extreme cases.
-- For analyzing the standard housing stock, it’s better to focus on the median to avoid distortion from rare units.


-- Статистические показатели по высоте потолков (м):
-- min_ceiling | max_ceiling | avg_ceiling | median_ceiling | perc99_ceiling
-- ----------- | ----------- | ----------- | -------------- | --------------
-- 1.00        | 100.00      | 2.77        | 2.65           | 3.82

-- Выводы:
-- • Минимальная высота потолков — 1 м, что явно некорректное значение и, вероятно, является ошибкой в данных.
-- • Максимальная высота — 100 м, также явно экстремальная ошибка (нереалистично для жилых помещений).
-- • Средняя высота — 2,77 м, что ближе к реальной норме стандартных квартир.
-- • Медиана — 2,65 м, отражает типичную высоту потолков для большинства объектов.
-- • 99-й перцентиль — 3,82 м, показывает верхний предел нормальных квартир (высокие потолки в элитных квартирах).
-- • Вывод: при анализе данных по потолкам необходимо фильтровать явные ошибки (например, <2 м или >6 м), чтобы получать корректные статистики.

-- Stats for apartment floors:
-- min_floor | max_floor | avg_floor | median_floor | perc99_floor
-- ---------- | ---------- | ---------- | ------------ | -------------
-- 1.00       | 33.00      | 5.89       | 4.00         | 23.00

-- Minimum floor — 1, corresponding to apartments on the first floor.
-- Maximum floor — 33, typical for high-rise buildings.
-- Average floor — 5.89, slightly above the median, indicating a small number of apartments on very high floors.
-- Median — 4, reflecting the typical floor for most apartments.
-- 99th percentile — 23, showing the upper limit for almost all apartments, excluding rare extreme cases on very high floors.
-- Conclusion: the floor distribution is skewed toward lower floors, with rare high-rise buildings.

-- 8
-- Identifying anomalous values (outliers) based on percentile thresholds:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Identifying the IDs of listings that do not contain outliers:
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
-- Displaying listings without outliers:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


