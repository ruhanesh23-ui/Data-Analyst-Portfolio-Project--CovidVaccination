# 🦠 COVID-19 Global Data Exploration — SQL

A data exploration project using Microsoft SQL Server (T-SQL) to analyse global COVID-19 trends across cases, deaths, and vaccination rollouts.

---

##  Project Overview

| File | Description |
|------|-------------|
| `covid_data_exploration.sql` | Full EDA — death rates, infection rates, vaccination progress, views |

**Tool:** Microsoft SQL Server / T-SQL  
**Dataset:** [Our World in Data — COVID-19](https://ourworldindata.org/covid-deaths)  
**Tables used:** `dbo.CovidDeaths` · `dbo.CovidVaccinations`

---

##  Dataset

The dataset covers COVID-19 statistics for countries and continents worldwide.

**CovidDeaths**

| Column | Description |
|--------|-------------|
| `location` | Country or continent name |
| `continent` | Continent (NULL when location = continent) |
| `date` | Date of record |
| `population` | Total population |
| `total_cases` | Cumulative confirmed cases |
| `new_cases` | New confirmed cases on that day |
| `total_deaths` | Cumulative confirmed deaths |
| `new_deaths` | New confirmed deaths on that day |

**CovidVaccinations**

| Column | Description |
|--------|-------------|
| `location` | Country name |
| `date` | Date of record |
| `new_vaccinations` | New vaccine doses administered on that day |

---

##  Analysis Breakdown

### Death & Infection Rates
- **Death rate over time** — what percentage of confirmed cases in the US resulted in death each day
- **Infection rate over time** — what percentage of the US population had confirmed COVID
- **Countries with highest infection rate** — ranked by peak % of population infected
- **Countries with highest death count** — absolute death toll by country
- **Continents with highest death count** — continental breakdown

### Global Trends
- **Daily global stats** — worldwide new cases, deaths, and death percentage per day
- **All-time global summary** — single-row total across the entire dataset

### Vaccination Progress
- **Rolling vaccination count** — cumulative doses administered per country using `SUM() OVER()`
- **% population vaccinated (CTE)** — derives vaccination rate on top of the rolling total
- **% population vaccinated (Temp Table)** — same result, stored in a temp table for reuse
- **Countries that crossed 50% vaccinated** — which countries hit the milestone and when

---

##  Views Created

Six reusable views were created to store query logic for reporting and dashboard tools (Tableau, Power BI):

| View | Purpose |
|------|---------|
| `vw_RollingVaccinations` | Rolling vaccination count per country per day |
| `vw_PercentPopulationVaccinated` | Vaccination rate as % of population |
| `vw_InfectionRateByCountry` | Peak infection rate vs population per country |
| `vw_DeathCountByCountry` | Total death count per country |
| `vw_DeathCountByContinent` | Total death count per continent |
| `vw_GlobalDailyStats` | Daily worldwide cases, deaths, and death % |

---

##  Key SQL Concepts Used

| Concept | Where used |
|---------|------------|
| `CAST()` | Converting `total_deaths`, `new_deaths`, `new_vaccinations` from TEXT/NVARCHAR to numeric |
| `NULLIF()` | Preventing divide-by-zero errors in rate calculations |
| `SUM() OVER (PARTITION BY ... ORDER BY ...)` | Rolling vaccination totals per country |
| `WITH ... AS (CTE)` | Computing vaccination % without a subquery |
| `DROP TABLE IF EXISTS` / Temp Tables | Reusable intermediate result sets |
| `CREATE OR ALTER VIEW` | Persisted query logic for dashboards |
| `JOIN` | Linking Deaths and Vaccinations on location + date |
| `WHERE continent IS NOT NULL` | Filtering out rows where location holds a continent name |

---

##  How to Run

1. Download the dataset from [Our World in Data](https://ourworldindata.org/covid-deaths) and import into SQL Server as two tables: `CovidDeaths` and `CovidVaccinations`
2. Run `covid_data_exploration.sql` from top to bottom in SSMS
3. The views at the bottom will be created in your database and available for Tableau or Power BI connections

> Tested on Microsoft SQL Server 2019+

---

##  What I Learned

- How `WHERE continent IS NOT NULL` is necessary to remove rows where the dataset uses continent names as location values — a non-obvious data quality issue
- Why `NULLIF(denominator, 0)` is better than `CASE WHEN` for safe division in calculated columns
- The difference between CTEs and Temp Tables — CTEs are cleaner for single-use logic; Temp Tables are better when you need to query the same intermediate result multiple times
- How window functions with `PARTITION BY` allow running totals without losing row-level detail
- How SQL views act as a clean interface between raw data and BI tools like Tableau

---

##  Repository Structure

```
├── covid_data_exploration.sql   # Full SQL analysis with views
└── README.md
```

---

##  About

Built as part of a guided SQL portfolio project. Queries, improvements, and additional views are my own.  
