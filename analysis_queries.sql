-- ============================================================
--  analysis_queries.sql
--  Employee Salary & Headcount Analysis
-- ------------------------------------------------------------
--  Table   : employees
--  Columns : EmployeeID, Name, Age, City, Salary, JoinDate
--  Engine  : MySQL 8+ (window functions required)
--
--  Every query below backs up a finding in the README.
--  Expected results are shown as comments (clean dataset = 9 rows).
-- ============================================================


-- ============================================================
-- SECTION 1 — DATA-QUALITY CHECKS
-- Run these FIRST. They are the cleaning story.
-- ============================================================

-- 1.1  Find duplicate records (same person entered twice)
--      Raw data had ID 1 and ID 4 identical (Alice).
SELECT Name, Age, City, Salary, JoinDate, COUNT(*) AS occurrences
FROM employees
GROUP BY Name, Age, City, Salary, JoinDate
HAVING COUNT(*) > 1;

-- 1.2  Find missing / blank values in critical columns
SELECT *
FROM employees
WHERE Name  IS NULL OR Name  = ''
   OR Age   IS NULL OR Age   <= 0        -- also catches impossible ages like -5
   OR City  IS NULL OR City  = ''
   OR Salary IS NULL OR Salary <= 0;

-- 1.3  Sanity-check salary range (catches the 900,000 typo)
SELECT MIN(Salary) AS min_salary,
       MAX(Salary) AS max_salary,
       AVG(Salary) AS avg_salary
FROM employees;
-- Result: 48000 | 90000 | 61611
--         (raw/raw-uncorrected data max = 900000 — a 10x typo)


-- ============================================================
-- SECTION 2 — HEADCOUNT & COMPOSITION
-- ============================================================

-- 2.1  Total headcount
SELECT COUNT(*) AS TotalEmployees
FROM employees;
-- Result: 9

-- 2.2  Headcount by city
SELECT City,
       COUNT(*) AS NumberOfEmployees
FROM employees
GROUP BY City
ORDER BY NumberOfEmployees DESC;
-- Result: Kisumu 3 | Nairobi 2 | Mombasa 2 | Eldoret 1 | Nakuru 1

-- 2.3  Each city's share of total headcount
SELECT City,
       COUNT(*) AS employees,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM employees), 1) AS pct_of_total
FROM employees
GROUP BY City
ORDER BY pct_of_total DESC;
-- Result: Kisumu 33.3% | Nairobi 22.2% | Mombasa 22.2% | Eldoret 11.1% | Nakuru 11.1%


-- ============================================================
-- SECTION 3 — SALARY ANALYSIS
-- ============================================================

-- 3.1  Total salary bill
SELECT SUM(Salary) AS TotalSalaryExpense
FROM employees;
-- Result: 554500

-- 3.2  Average vs median salary
--      The gap between them is the key insight: the distribution is right-skewed.
SELECT AVG(Salary) AS AverageSalary
FROM employees;
-- Result: 61611.11  (rounded: 61611)

SELECT AVG(Salary) AS MedianSalary
FROM (
    SELECT Salary,
           ROW_NUMBER() OVER (ORDER BY Salary) AS rn,
           COUNT(*)     OVER ()                AS cnt
    FROM employees
) t
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));
-- Result: 59500  →  median (59500) < mean (61611) → right-skewed

-- 3.3  Highest and lowest earners
SELECT Name, Salary
FROM employees
ORDER BY Salary DESC
LIMIT 1;
-- Result: George | 90000

SELECT Name, Salary
FROM employees
ORDER BY Salary ASC
LIMIT 1;
-- Result: Evan | 48000

-- 3.4  Ties handled properly (returns EVERY employee at the top salary)
SELECT Name, Salary
FROM (
    SELECT Name, Salary, RANK() OVER (ORDER BY Salary DESC) AS salary_rank
    FROM employees
) ranked
WHERE salary_rank = 1;

-- 3.5  Employees earning above the company average
SELECT Name, Salary
FROM employees
WHERE Salary > (SELECT AVG(Salary) FROM employees)
ORDER BY Salary DESC;
-- Result: George 90000 | Diana 70000 | Bob 62000
--         → 3 of 9 (33%) earn above the mean, a symptom of skew


-- ============================================================
-- SECTION 4 — CITY ANALYSIS
-- ============================================================

-- 4.1  Average salary per city
SELECT City,
       ROUND(AVG(Salary), 0) AS AverageSalary
FROM employees
GROUP BY City
ORDER BY AverageSalary DESC;
-- Result: Nairobi 72500 | Kisumu 63500 | Mombasa 60000 | Eldoret 51000 | Nakuru 48000

-- 4.2  Highest salary in each city
SELECT City,
       MAX(Salary) AS MaxSalaryPerCity
FROM employees
GROUP BY City
ORDER BY MaxSalaryPerCity DESC;

-- 4.3  How far each city sits above/below the company average
SELECT City,
       ROUND(AVG(Salary), 0) AS city_avg,
       ROUND(AVG(Salary) - (SELECT AVG(Salary) FROM employees), 0) AS vs_company_avg
FROM employees
GROUP BY City
ORDER BY vs_company_avg DESC;
-- Result: Nairobi +10889 (+17.7%) ... Nakuru -13611 (-22%)

-- 4.4  Employees in a specific city
SELECT *
FROM employees
WHERE City = 'Nairobi';      -- single quotes: portable and ANSI-safe
-- Result: Alice | George


-- ============================================================
-- SECTION 5 — AGE ANALYSIS
-- ============================================================

-- 5.1  Average and range of employee age
SELECT ROUND(AVG(Age), 1) AS AverageAge,
       MIN(Age) AS Youngest,
       MAX(Age) AS Oldest
FROM employees;
-- Result: 30.3 | 25 | 40

-- 5.2  Employees under 30
SELECT Name, Age
FROM employees
WHERE Age < 30
ORDER BY Age;
-- Result: Alice 25 | Evan 27 | Hassan 28 | Bob 29 | Charlie 29 | Faith 29

-- 5.3  Age vs pay — shows age is the strongest salary driver here
SELECT Name, Age, Salary
FROM employees
ORDER BY Age;
-- Pay rises monotonically with age: 25→55000 ... 40→90000 (1.88x gap)


-- ============================================================
-- SECTION 6 — HIRING TREND OVER TIME
-- ============================================================

-- 6.1  Employees hired after 31 March 2025 (strictly after)
SELECT Name, JoinDate
FROM employees
WHERE JoinDate > '2025-03-31'
ORDER BY JoinDate;
-- Result: Faith | George | Jamal | Hassan  (JoinDate must be a DATE column)

-- 6.2  Hires per month
SELECT DATE_FORMAT(JoinDate, '%Y-%m') AS MonthJoined,
       COUNT(*)                       AS Employees
FROM employees
GROUP BY DATE_FORMAT(JoinDate, '%Y-%m')
ORDER BY MonthJoined;
-- Result: 2025-01:1 | 2025-02:2 | 2025-03:2 | 2025-04:2 | 2025-05:2

-- 6.3  Cumulative headcount growth (running total)
SELECT DATE_FORMAT(JoinDate, '%Y-%m') AS MonthJoined,
       COUNT(*)                       AS HiresThisMonth,
       SUM(COUNT(*)) OVER (ORDER BY DATE_FORMAT(JoinDate, '%Y-%m')) AS CumulativeHeadcount
FROM employees
GROUP BY DATE_FORMAT(JoinDate, '%Y-%m')
ORDER BY MonthJoined;
-- Result: Jan 1/1, Feb 2/3, Mar 2/5, Apr 2/7, May 2/9


-- ============================================================
-- SECTION 7 — OUTLIER DETECTION (Tukey / IQR method)
-- Flags salaries outside Q1 - 1.5*IQR and Q3 + 1.5*IQR.
-- For this data: Q1 = 53000, Q3 = 66000, IQR = 13000
--               upper fence = 85500  →  George (90000) is an outlier
-- ============================================================
WITH ordered AS (
    SELECT Salary,
           ROW_NUMBER() OVER (ORDER BY Salary) AS rn,
           COUNT(*)     OVER ()                AS n
    FROM employees
),
halves AS (
    SELECT Salary,
           CASE
             WHEN rn <= FLOOR(n / 2)     THEN 'lower'
             WHEN rn >  n - FLOOR(n / 2) THEN 'upper'
           END AS half
    FROM ordered
),
quartiles AS (
    SELECT
        (SELECT AVG(Salary) FROM (
            SELECT Salary,
                   ROW_NUMBER() OVER (ORDER BY Salary) AS r,
                   COUNT(*)     OVER ()                AS c
            FROM halves WHERE half = 'lower'
        ) x WHERE r IN (FLOOR((c + 1) / 2), CEIL((c + 1) / 2))) AS q1,
        (SELECT AVG(Salary) FROM (
            SELECT Salary,
                   ROW_NUMBER() OVER (ORDER BY Salary) AS r,
                   COUNT(*)     OVER ()                AS c
            FROM halves WHERE half = 'upper'
        ) x WHERE r IN (FLOOR((c + 1) / 2), CEIL((c + 1) / 2))) AS q3
)
SELECT e.Name,
       e.Salary,
       q.q1,
       q.q3,
       (q.q3 - q.q1)                  AS iqr,
       (q.q3 + 1.5 * (q.q3 - q.q1))   AS upper_fence
FROM employees e
CROSS JOIN quartiles q
WHERE e.Salary > q.q3 + 1.5 * (q.q3 - q.q1)
   OR e.Salary < q.q1 - 1.5 * (q.q3 - q.q1);
-- Result: George | 90000 | 53000 | 66000 | 13000 | 85500
