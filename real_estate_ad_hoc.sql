/* Project of Module 1: Data Analysis for a Real Estate Agency
 * Part 2. Solving Ad Hoc Tasks
 *
*/

-- Task 1: Listing Activity Time
-- Identify anomalous values (outliers) using percentile thresholds:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Let’s find the IDs of listings that don’t contain outliers, and also keep the missing data:
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
-- We use the ad IDs (CTE filtered_id) that don’t contain outliers in the data analysis
filtered_stats AS (
    SELECT
        a.id,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        f.ceiling_height,
        f.kitchen_area,
        f.living_area,
        c.city
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON t.type_id = f.type_id
    WHERE a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
      AND f.id IN (SELECT id FROM filtered_id)
      AND t.type = 'город' 
),
categorized AS (
    SELECT
        *,
        CASE
        WHEN days_exposition IS NULL OR days_exposition < 1 THEN 'non category'
        WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
        WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
        WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
        WHEN days_exposition >= 181 THEN '181+ days'
        END AS activity_category,
        ROUND(CAST(last_price / NULLIF(total_area, 0) AS numeric), 2) AS price_per_sqm
    FROM filtered_stats
),
region_cat AS (
    SELECT
        *,
        CASE
            WHEN city = 'Санкт-Петербург' THEN 'spb'
            ELSE 'region'
        END AS region_vs_city
    FROM categorized
)
SELECT
      region_vs_city,
      activity_category,
      COUNT(*) AS ads_count,
      ROUND(AVG(price_per_sqm::numeric), 0) AS avg_price_per_sqm,
      ROUND((CAST(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY price_per_sqm::double precision) AS numeric)), 0) AS median_price_per_sqm,
      ROUND(AVG(total_area::numeric), 1) AS avg_total_area,
      ROUND((CAST(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY total_area::double precision) AS numeric)), 1) AS median_total_area,
      ROUND(AVG(rooms::numeric), 1) AS avg_rooms,
      ROUND(AVG(balcony::numeric), 1) AS avg_balcony
FROM region_cat
GROUP BY region_vs_city, activity_category
ORDER BY
    region_vs_city,
    CASE activity_category
        WHEN '1-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181+ days' THEN 4
        ELSE 5
    END;

-- region_vs_city   activity_category   ads_count   avg_price_per_sqm   median_price_per_sqm   avg_total_area   median_total_area   avg_rooms   avg_balcony
-- region           1-30 days           340         71908               70000                  48.8             44.0                1.7         1.0
-- region           31-90 days          864         67424               66173                  50.9             47.0                1.9         0.9
-- region           91-180 days         553         69809               68800                  51.8             50.0                1.9         0.9
-- region           181+ days           873         68215               66978                  55.0             51.5                2.0         0.9
-- region           non category        198         72926               70270                  62.8             59.7                2.2         1.6
-- spb              1-30 days           1794        108920              102062                 54.7             49.0                1.9         1.0
-- spb              31-90 days          3020        110874              103641                 56.6             50.6                1.9         1.0
-- spb              91-180 days         2244        111974              103878                 60.5             55.0                2.0         0.9
-- spb              181+ days           3506        114981              104603                 65.8             59.6                2.2         0.9
-- spb              non category        653         136108              125000                 81.4             75.0                2.5         1.6
-- In both regions, listings with medium and long activity periods — from 31 days to over 6 months — dominate, while quick sales (up to one month) make up a smaller share of the market.
-- Apartments in St. Petersburg are significantly more expensive than in the Leningrad Region.
-- In St. Petersburg, the average apartment size has a stronger impact on the increase in selling time compared to properties in the Leningrad Region.
-- The average number of rooms and balconies affects the selling speed less in both St. Petersburg and the Leningrad Region.
-- The difference may be explained by the fact that the Leningrad Region has a more homogeneous real estate market (in terms of apartment size and price),
-- so the correlation is weaker, while St. Petersburg has large luxury apartments that naturally take longer to sell.


-- Task 2: Seasonality of Listings
-- Identify anomalous values (outliers) based on percentile values:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Finding the ads' IDs that don’t contain outliers, while keeping the missing data:
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
-- Using the ad IDs (СТЕ filtered_id) that do not contain outliers when analyzing the data
 months_filtered AS (
    SELECT
        a.id,
        f.total_area,
        a.last_price,
        f.city_id,
        t.type,
        a.first_day_exposition,
        a.days_exposition,
        EXTRACT(MONTH FROM a.first_day_exposition) AS publish_month_num,
        TO_CHAR(a.first_day_exposition, 'TMMonth') AS publish_month,
        EXTRACT(MONTH FROM (a.first_day_exposition + INTERVAL '1 day' * a.days_exposition)) AS removal_month_num,
        TO_CHAR((a.first_day_exposition + INTERVAL '1 day' * a.days_exposition), 'TMMonth') AS removal_month
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE a.id IN (SELECT id FROM filtered_id)
      AND t.type = 'город'
      AND a.first_day_exposition BETWEEN DATE '2015-01-01' AND DATE '2018-12-31'
),
--monthly statistics of ad postings, sales launches
publish_stats AS (
    SELECT
        publish_month_num AS month_num,
        publish_month AS month_of_action,
        COUNT(*) AS id_count,
        ROUND(AVG(last_price / total_area)::NUMERIC,2) AS avg_price_per_m,
        ROUND(AVG(total_area)::NUMERIC,2) AS avg_area,
        'published' AS type_of_action
    FROM months_filtered
    GROUP BY publish_month_num, publish_month
),
--statistics on ads that were removed
removal_stats AS (
    SELECT
        removal_month_num AS month_num,
        removal_month AS month_of_action,
        COUNT(*) AS id_count,
        ROUND(AVG(last_price / total_area)::NUMERIC,2) AS avg_price_per_m,
        ROUND(AVG(total_area)::NUMERIC,2) AS avg_area,
        'removal' AS type_of_action
    FROM months_filtered
    WHERE days_exposition IS NOT NULL
    GROUP BY removal_month_num, removal_month
),
combined_stats AS (
    SELECT * FROM publish_stats
    UNION ALL
    SELECT * FROM removal_stats
)
SELECT *
FROM combined_stats
ORDER BY 
    CASE type_of_action
        WHEN 'published' THEN 1
        WHEN 'removal' THEN 2
    END,
    month_num;
-- | #  | Month     | Count | Avg Price/m² | Avg Area | Type      |
-- |----|-----------|-------|--------------|----------|-----------|
-- | 1  | January   | 735   | 106106.24    | 59.16    | published |
-- | 2  | February  | 1369  | 103058.51    | 60.10    | published |
-- | 3  | March     | 1119  | 102429.95    | 60.00    | published |
-- | 4  | April     | 1021  | 102632.41    | 60.60    | published |
-- | 5  | May       | 891   | 102465.12    | 59.19    | published |
-- | 6  | June      | 1224  | 104802.15    | 58.37    | published |
-- | 7  | July      | 1149  | 104488.96    | 60.42    | published |
-- | 8  | August    | 1166  | 107034.70    | 58.99    | published |
-- | 9  | September | 1341  | 107563.12    | 61.04    | published |
-- | 10 | October   | 1437  | 104065.11    | 59.43    | published |
-- | 11 | November  | 1569  | 105048.80    | 59.58    | published |
-- | 12 | December  | 1024  | 104775.39    | 58.84    | published |
-- | 1  | January   | 1225  | 104947.31    | 57.53    | removal   |
-- | 2  | February  | 1048  | 103883.72    | 61.12    | removal   |
-- | 3  | March     | 1071  | 106832.40    | 60.37    | removal   |
-- | 4  | April     | 1031  | 102444.24    | 59.22    | removal   |
-- | 5  | May       | 729   | 99724.07     | 57.78    | removal   |
-- | 6  | June      | 771   | 101863.69    | 59.82    | removal   |
-- | 7  | July      | 1108  | 102290.72    | 58.54    | removal   |
-- | 8  | August    | 1137  | 100036.51    | 56.83    | removal   |
-- | 9  | September | 1238  | 104070.07    | 57.49    | removal   |
-- | 10 | October   | 1360  | 104317.33    | 58.86    | removal   |
-- | 11 | November  | 1301  | 103791.36    | 56.71    | removal   |
-- | 12 | December  | 1175  | 105504.52    | 59.26    | removal   |

--Real estate sellers are active in the autumn months (Sep–Oct–Nov, especially November)
--and in February. Buyers are active in Sep–Oct and Dec–Jan, with a relative
--peak of activity in March. Listings appear 1–2 months before sales, reflecting the sales cycle.
--At the beginning of the year (Jan–Feb) and early summer (May–Jul), properties with
--relatively high price per square meter (102–107k/m²) are listed. The average
--size of properties is also slightly higher in the winter months (Jan–Feb) and in autumn
--(Sep–Oct), when sellers list apartments most frequently.
--The average size of listed properties is higher in summer (Jun–Aug). The peak average
--price per square meter occurs in March and September (99–106k/m²), while the maximum
--average property sizes are observed in Feb–Mar and Sep–Oct.



