-- ============================================================
-- PROJECT: COVID-19 Global Data Exploration
-- Author:  Ruhanesh Suthan
-- Tool:    Microsoft SQL Server (T-SQL)
-- Dataset: https://ourworldindata.org/covid-deaths
-- Tables:  dbo.CovidDeaths | dbo.CovidVaccinations
-- Guidence: Alex the Analyst
-- ============================================================
-- Goal:
--   Explore global COVID-19 data to uncover trends in:
--   - Death rates and infection rates by country
--   - Continental death counts
--   - Global daily case and death progression
--   - Vaccination rollout vs population
-- ============================================================


-- ============================================================
-- 1. PREVIEW RAW DATA
-- ============================================================

SELECT *
FROM dbo.CovidDeaths
ORDER BY location, date;

SELECT *
FROM dbo.CovidVaccinations
ORDER BY location, date;


-- ============================================================
-- 2. SELECT CORE COLUMNS FOR ANALYSIS
-- ============================================================

SELECT
    location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL  -- removes rows where location = continent name
ORDER BY location, date;


-- ============================================================
-- 3. DEATH RATE BY COUNTRY OVER TIME
-- ============================================================
-- What percentage of confirmed COVID cases resulted in death?
-- Filtered to United States as an example.

SELECT
    location,
    date,
    total_cases,
    total_deaths,
    (CAST(total_deaths AS FLOAT) / NULLIF(total_cases, 0)) * 100 AS death_rate_pct
FROM dbo.CovidDeaths
WHERE location LIKE '%states%'
  AND continent IS NOT NULL
ORDER BY location, date;


-- ============================================================
-- 4. INFECTION RATE VS POPULATION BY COUNTRY OVER TIME
-- ============================================================
-- What percentage of the population contracted COVID?

SELECT
    location,
    date,
    population,
    total_cases,
    (CAST(total_cases AS FLOAT) / NULLIF(population, 0)) * 100 AS case_rate_pct
FROM dbo.CovidDeaths
WHERE location LIKE '%states%'
  AND continent IS NOT NULL
ORDER BY location, date;


-- ============================================================
-- 5. COUNTRIES WITH HIGHEST INFECTION RATE VS POPULATION
-- ============================================================
-- Which countries had the highest share of their population infected?

SELECT
    location,
    population,
    MAX(total_cases)                                              AS highest_infection_count,
    MAX(CAST(total_cases AS FLOAT) / NULLIF(population, 0)) * 100 AS pct_population_infected
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY pct_population_infected DESC;


-- ============================================================
-- 6. COUNTRIES WITH HIGHEST TOTAL DEATH COUNT
-- ============================================================

SELECT
    location,
    MAX(CAST(total_deaths AS INT)) AS total_death_count
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC;


-- ============================================================
-- 7. CONTINENTS WITH HIGHEST TOTAL DEATH COUNT
-- ============================================================

SELECT
    continent,
    MAX(CAST(total_deaths AS INT)) AS total_death_count
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC;


-- ============================================================
-- 8. GLOBAL DAILY CASE AND DEATH TOTALS
-- ============================================================
-- Worldwide new cases, new deaths, and death rate per day.

SELECT
    date,
    SUM(new_cases)                                              AS total_new_cases,
    SUM(CAST(new_deaths AS INT))                               AS total_new_deaths,
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(new_cases), 0) * 100 AS global_death_pct
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date;


-- ============================================================
-- 9. GLOBAL SUMMARY (ALL TIME)
-- ============================================================
-- Single row: total cases, total deaths, and overall death rate
-- across the entire dataset.

SELECT
    SUM(new_cases)                                              AS total_cases,
    SUM(CAST(new_deaths AS INT))                               AS total_deaths,
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(new_cases), 0) * 100 AS global_death_pct
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;


-- ============================================================
-- 10. ROLLING VACCINATION COUNT PER COUNTRY
-- ============================================================
-- How many people in each country have received at least one
-- vaccine dose, tracked cumulatively over time?

SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
    ) AS rolling_vaccinations
FROM dbo.CovidDeaths AS dea
JOIN dbo.CovidVaccinations AS vac
    ON  dea.location = vac.location
    AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.date;


-- ============================================================
-- 11. % POPULATION VACCINATED OVER TIME — CTE METHOD
-- ============================================================
-- Derive vaccination rate from the rolling total above.
-- CTE avoids repeating the window function in a subquery.

WITH PopvsVac (continent, location, date, population, new_vaccinations, rolling_vaccinations) AS
(
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (
            PARTITION BY dea.location
            ORDER BY dea.date
        ) AS rolling_vaccinations
    FROM dbo.CovidDeaths AS dea
    JOIN dbo.CovidVaccinations AS vac
        ON  dea.location = vac.location
        AND dea.date     = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    *,
    (rolling_vaccinations / NULLIF(population, 0)) * 100 AS pct_population_vaccinated
FROM PopvsVac
ORDER BY location, date;


-- ============================================================
-- 12. % POPULATION VACCINATED — TEMP TABLE METHOD
-- ============================================================
-- Alternative to CTE — useful when you need to reuse results
-- across multiple subsequent queries in the same session.

DROP TABLE IF EXISTS #PercentPopulationVaccinated;

CREATE TABLE #PercentPopulationVaccinated (
    continent             NVARCHAR(255),
    location              NVARCHAR(255),
    date                  DATETIME,
    population            FLOAT,
    new_vaccinations      BIGINT,
    rolling_vaccinations  BIGINT
);

INSERT INTO #PercentPopulationVaccinated
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    CAST(vac.new_vaccinations AS BIGINT),
    SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
    ) AS rolling_vaccinations
FROM dbo.CovidDeaths AS dea
JOIN dbo.CovidVaccinations AS vac
    ON  dea.location = vac.location
    AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL;

SELECT
    *,
    (rolling_vaccinations / NULLIF(population, 0)) * 100 AS pct_population_vaccinated
FROM #PercentPopulationVaccinated
ORDER BY location, date;


-- ============================================================
-- 13. COUNTRIES THAT REACHED 50% VACCINATION
-- ============================================================
-- Using the temp table — which countries ever crossed the
-- 50% vaccinated threshold, and when did they first do so?

SELECT
    location,
    MIN(date) AS date_reached_50pct,
    MAX((rolling_vaccinations / NULLIF(population, 0)) * 100) AS peak_vax_pct
FROM #PercentPopulationVaccinated
WHERE (rolling_vaccinations / NULLIF(population, 0)) * 100 >= 50
GROUP BY location
ORDER BY date_reached_50pct;


-- ============================================================
-- VIEWS — Stored for reporting / Tableau / Power BI
-- ============================================================
-- Views save the query logic so it can be reused without
-- re-writing SQL. Useful for connecting to dashboards.


-- View 1: Rolling vaccination progress
-- -------------------------------------------------------
CREATE OR ALTER VIEW vw_RollingVaccinations AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
    ) AS rolling_vaccinations
FROM dbo.CovidDeaths AS dea
JOIN dbo.CovidVaccinations AS vac
    ON  dea.location = vac.location
    AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL;

SELECT * FROM vw_RollingVaccinations;


-- View 2: Percent of population vaccinated per country per day
-- -------------------------------------------------------
CREATE OR ALTER VIEW vw_PercentPopulationVaccinated AS
SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    rolling_vaccinations,
    (rolling_vaccinations / NULLIF(population, 0)) * 100 AS pct_population_vaccinated
FROM vw_RollingVaccinations;

SELECT * FROM vw_PercentPopulationVaccinated ORDER BY location, date;


-- View 3: Country-level infection rate vs population
-- -------------------------------------------------------
CREATE OR ALTER VIEW vw_InfectionRateByCountry AS
SELECT
    location,
    population,
    MAX(total_cases)                                               AS highest_infection_count,
    MAX(CAST(total_cases AS FLOAT) / NULLIF(population, 0)) * 100 AS pct_population_infected
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population;

SELECT * FROM vw_InfectionRateByCountry ORDER BY pct_population_infected DESC;


-- View 4: Country-level death count (for map visualisations)
-- -------------------------------------------------------
CREATE OR ALTER VIEW vw_DeathCountByCountry AS
SELECT
    location,
    MAX(CAST(total_deaths AS INT)) AS total_death_count
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location;

SELECT * FROM vw_DeathCountByCountry ORDER BY total_death_count DESC;


-- View 5: Continental death count summary
-- -------------------------------------------------------
CREATE OR ALTER VIEW vw_DeathCountByContinent AS
SELECT
    continent,
    MAX(CAST(total_deaths AS INT)) AS total_death_count
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent;

SELECT * FROM vw_DeathCountByContinent ORDER BY total_death_count DESC;


-- View 6: Global daily case and death summary
-- -------------------------------------------------------
CREATE OR ALTER VIEW vw_GlobalDailyStats AS
SELECT
    date,
    SUM(new_cases)                                                  AS total_new_cases,
    SUM(CAST(new_deaths AS INT))                                   AS total_new_deaths,
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(new_cases), 0) * 100 AS global_death_pct
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date;

SELECT * FROM vw_GlobalDailyStats ORDER BY date;


-- ============================================================
-- SQL CONCEPTS USED IN THIS PROJECT
-- ============================================================
--
-- AGGREGATE FUNCTIONS  → SUM(), MAX(), MIN()
-- CAST / NULLIF        → Safe type conversion and divide-by-zero protection
-- WINDOW FUNCTIONS     → SUM() OVER (PARTITION BY ... ORDER BY ...)
-- CTEs                 → WITH ... AS (...)
-- TEMP TABLES          → DROP TABLE IF EXISTS / CREATE TABLE / INSERT INTO
-- VIEWS                → CREATE OR ALTER VIEW
-- JOINS                → INNER JOIN on location + date
-- FILTERING            → WHERE continent IS NOT NULL
--
-- ============================================================
-- BUSINESS QUESTIONS ANSWERED
-- ============================================================
-- ✓ Daily death rate for the United States
-- ✓ Daily infection rate for the United States
-- ✓ Countries with highest infection rate vs population
-- ✓ Countries with highest absolute death count
-- ✓ Continents with highest death count
-- ✓ Global daily cases, deaths, and death percentage
-- ✓ Global all-time summary
-- ✓ Rolling vaccination count per country
-- ✓ % of population vaccinated over time (CTE + Temp Table)
-- ✓ Countries that crossed the 50% vaccination milestone
-- ✓ Six reusable views created for dashboard use
