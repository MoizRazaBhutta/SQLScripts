USE JOB_PORTAL_DB

-- 1. Identify the users who try to logon before 2017 but never try to logon during 2017. Eliminate duplicate lines from your output.
SELECT SL.Login as [User Login], SL.Full_Name as [User Name], SL.Phone_Number as [User Phone]
FROM [dbo].[Security_Logins] SL
JOIN [dbo].[Security_Logins_Log] SLL
ON SL.Id = SLL.Login
WHERE SLL.Logon_Date <= '2016-12-31'
EXCEPT
SELECT SL.Login, SL.Full_Name, SL.Phone_Number
FROM [dbo].[Security_Logins] SL
JOIN [dbo].[Security_Logins_Log] SLL
ON SL.Id = SLL.Login
WHERE SLL.Logon_Date > '2016-12-31'
ORDER BY SL.Login;


-- 2. Identify the companies where applicants applied for the job 10 or more times.
-- Eliminate duplicate lines from your output. (9 records expected Tables: [dbo].[Applicant_Job_Applications], [dbo].[Company_Jobs], [dbo].[Company_Descriptions] )
SELECT CD.Company_Name AS [Company Name] FROM [dbo].[Applicant_Job_Applications] AP
JOIN [dbo].[Company_Jobs] CJ
ON AP.Job = CJ.Id
JOIN [dbo].[Company_Descriptions] CD
ON CJ.Company = CD.Company AND CD.LanguageID = 'EN'
GROUP BY CD.Company_Name
HAVING COUNT(AP.Job) >= 10
ORDER BY CD.Company_Name;


-- 3. Identify the Applicants with highest current salary for each Currency.
--(2 records expected Tables: [dbo].[Applicant_Profiles], [dbo].[Security_Logins])
SELECT SL.Login, AP.Current_Salary AS [Current Salary], AP.Currency
FROM [dbo].[Applicant_Profiles] AP
JOIN [dbo].[Security_Logins] SL
ON AP.Login = SL.Id
WHERE AP.Current_Salary in (
SELECT MAX(AP2.Current_Salary) FROM [dbo].Applicant_Profiles AP2
WHERE AP2.Currency = AP.Currency
);

--4. For each company, determine the number of jobs posted. If a company doesn't have posted jobs, show 0 for that company.
--(200 records expected Tables: [dbo].[Company_Profiles], [dbo].[Company_Descriptions], [dbo].[Company_Jobs])

SELECT CD.Company_Name,COUNT(CJ.Company) AS [Jobs Posted]
FROM [dbo].[Company_Jobs] CJ
RIGHT JOIN [dbo].[Company_Profiles] CP
ON CJ.Company = CP.Id
JOIN [dbo].[Company_Descriptions] CD
ON CD.Company = CP.Id AND CD.LanguageID = 'EN'
GROUP BY CD.Company_Name
ORDER BY [Jobs Posted];

-- 5. Determine the total number of companies that have posted jobs and the total number of companies that have never posted jobs in one data set with 2 rows
SELECT 'Clients with Posted Jobs:',COUNT(*) FROM
(SELECT CP.Id
FROM [dbo].[Company_Jobs] CJ
JOIN [dbo].[Company_Profiles] CP
ON CJ.Company = CP.Id
GROUP BY CP.Id) A
UNION
SELECT 'Clients without Posted Jobs',COUNT(*) FROM
(SELECT COUNT(CJ.Company) AS [Job Posted],CP.Id
FROM [dbo].[Company_Jobs] CJ
RIGHT JOIN [dbo].[Company_Profiles] CP
ON CJ.Company = CP.Id
GROUP BY CP.Id HAVING COUNT(CJ.Company) = 0) B;