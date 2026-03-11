/* ================================================================================
PROJECT: Nashville Housing Data Analysis
AUTHOR: Keerti Upadhyay
DESCRIPTION: This script covers data cleaning and exploratory analysis of the 
             Nashville housing dataset. 
             - Cleaning: Addressing address inconsistencies and standardizing fields.
             - Analysis: Extracting key market trends and appreciation metrics.
================================================================================
*/

-- =============================================================================
-- 1. DATA CLEANING
-- =============================================================================
/* Objective: Standardize dates, split address components for better granularity, 
   and normalize 'Sold As Vacant' entries.
*/

CREATE OR REPLACE TABLE `sql-project-487319.NashvilleData.nashville_cleaned` AS
SELECT 
    -- Convert string dates to standard DATE format
    SAFE.PARSE_DATE('%Y-%m-%d', CAST(`Sale Date` AS STRING)) AS SaleDate,
    
    -- Address Splitting: Use COALESCE to prioritize comma-split; 
    -- fallback to 'Property City' if comma is absent.
    TRIM(SPLIT(`Property Address`, ',')[SAFE_OFFSET(0)]) AS PropertySplitAddress,
    
    COALESCE(
        TRIM(SPLIT(`Property Address`, ',')[SAFE_OFFSET(1)]), 
        `Property City`
    ) AS PropertySplitCity,
    
    -- Normalize 'Sold As Vacant' (Y/N to Yes/No)
    CASE 
        WHEN CAST(`Sold As Vacant` AS STRING) IN ('Y', 'Yes') THEN 'Yes'
        WHEN CAST(`Sold As Vacant` AS STRING) IN ('N', 'No') THEN 'No'
        ELSE CAST(`Sold As Vacant` AS STRING) 
    END AS SoldAsVacant,
    
    -- Retain remaining columns
    * EXCEPT(`Property Address`, `Sale Date`, `Sold As Vacant`, `Property City`)
FROM `sql-project-487319.NashvilleData.nashville`;


-- =============================================================================
-- 2. EXPLORATORY DATA ANALYSIS (EDA)
-- =============================================================================

-- Insight A: Average Sale Price by City
SELECT 
    PropertySplitCity AS city, 
    ROUND(AVG(`Sale Price`), 2) AS AvgSalePrice
FROM `sql-project-487319.NashvilleData.nashville_cleaned`
GROUP BY 1
ORDER BY 2 DESC;

-- Insight B: Sales Trends Over Time
SELECT 
    EXTRACT(YEAR FROM SaleDate) AS SaleYear,
    COUNT(*) AS TotalSales
FROM `sql-project-487319.NashvilleData.nashville_cleaned`
WHERE SaleDate IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Insight C: Top 5 Neighborhoods with Most Sales
SELECT 
    Neighborhood, 
    COUNT(*) AS TotalSales
FROM `sql-project-487319.NashvilleData.nashville_cleaned`
WHERE Neighborhood IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

-- =============================================================================
-- 3. ADVANCED ANALYSIS: Property Appreciation
-- =============================================================================
/* Objective: Analyze year-over-year (YoY) market performance.
   Methodology: Use CTEs to calculate annual averages, then the LAG() window 
   function to compare current-year prices against the previous year.
*/

WITH AnnualStats AS (
    SELECT 
        EXTRACT(YEAR FROM SaleDate) AS SaleYear,
        AVG(`Sale Price`) AS AvgSalePrice
    FROM `sql-project-487319.NashvilleData.nashville_cleaned`
    WHERE SaleDate IS NOT NULL
    GROUP BY 1
),
YearOverYear AS (
    SELECT 
        SaleYear,
        AvgSalePrice,
        LAG(AvgSalePrice) OVER (ORDER BY SaleYear) AS PrevYearPrice
    FROM AnnualStats
)
SELECT 
    SaleYear,
    ROUND(AvgSalePrice, 2) AS AveragePrice,
    ROUND(((AvgSalePrice - PrevYearPrice) / PrevYearPrice) * 100, 2) AS YoY_Growth_Percent
FROM YearOverYear
ORDER BY SaleYear;