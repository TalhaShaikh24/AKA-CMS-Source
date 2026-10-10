/* ============================================================
   AKA-CMS — Geography master tables (Regions, Local Councils,
   Villages) for the case registration form.
   Dynamic master data: users can add/edit these from the web UI
   and the Register Case dropdowns reflect them immediately.
   Additive and safe to re-run.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------- CMS_Regions ---------------- */
IF OBJECT_ID(N'[dbo].[CMS_Regions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Regions](
        [RegionId] INT IDENTITY(1,1) NOT NULL,
        [RegionName] NVARCHAR(100) NOT NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_Regions_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_Regions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_Regions_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_Regions] PRIMARY KEY CLUSTERED ([RegionId] ASC),
        CONSTRAINT [UX_CMS_Regions_Name] UNIQUE NONCLUSTERED ([RegionName] ASC)
    );
END
GO

/* ---------------- CMS_LocalCouncils ---------------- */
IF OBJECT_ID(N'[dbo].[CMS_LocalCouncils]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_LocalCouncils](
        [CouncilId] INT IDENTITY(1,1) NOT NULL,
        [RegionId] INT NULL,
        [CouncilName] NVARCHAR(100) NOT NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_LocalCouncils_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_LocalCouncils_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_LocalCouncils_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_LocalCouncils] PRIMARY KEY CLUSTERED ([CouncilId] ASC),
        CONSTRAINT [UX_CMS_LocalCouncils_Name] UNIQUE NONCLUSTERED ([CouncilName] ASC),
        CONSTRAINT [FK_CMS_LocalCouncils_Region] FOREIGN KEY ([RegionId])
            REFERENCES [dbo].[CMS_Regions] ([RegionId])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_LocalCouncils_Region] ON [dbo].[CMS_LocalCouncils] ([RegionId] ASC);
END
GO

/* ---------------- CMS_Villages ---------------- */
IF OBJECT_ID(N'[dbo].[CMS_Villages]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Villages](
        [VillageId] INT IDENTITY(1,1) NOT NULL,
        [CouncilId] INT NULL,
        [VillageName] NVARCHAR(100) NOT NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_Villages_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_Villages_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_Villages_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_Villages] PRIMARY KEY CLUSTERED ([VillageId] ASC),
        CONSTRAINT [UX_CMS_Villages_Name] UNIQUE NONCLUSTERED ([VillageName] ASC),
        CONSTRAINT [FK_CMS_Villages_Council] FOREIGN KEY ([CouncilId])
            REFERENCES [dbo].[CMS_LocalCouncils] ([CouncilId])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_Villages_Council] ON [dbo].[CMS_Villages] ([CouncilId] ASC);
END
GO

/* ---------------- Seed: Regions (from the CMO design form) ---------------- */
MERGE INTO [dbo].[CMS_Regions] AS t
USING (VALUES
    (N'Gilgit'), (N'Ghizer'), (N'Hunza'), (N'Nagar'),
    (N'Skardu'), (N'Ghanche'), (N'Astore'), (N'Diamer')
) AS s ([RegionName])
ON t.[RegionName] = s.[RegionName]
WHEN NOT MATCHED THEN
    INSERT ([RegionName], [CreatedBy], [IpAddress])
    VALUES (s.[RegionName], 1, '127.0.0.1');
GO

/* ---------------- Seed: Local Councils ---------------- */
MERGE INTO [dbo].[CMS_LocalCouncils] AS t
USING (
    SELECT r.[RegionId], s.[CouncilName]
    FROM (VALUES
        (N'Gilgit',  N'Gilgit City'),
        (N'Gilgit',  N'Danyor'),
        (N'Hunza',   N'Gojal'),
        (N'Hunza',   N'Aliabad'),
        (N'Ghizer',  N'Booni'),
        (NULL,       N'Other')
    ) AS s ([RegionName], [CouncilName])
    LEFT JOIN [dbo].[CMS_Regions] AS r ON r.[RegionName] = s.[RegionName]
) AS s ([RegionId], [CouncilName])
ON t.[CouncilName] = s.[CouncilName]
WHEN NOT MATCHED THEN
    INSERT ([RegionId], [CouncilName], [CreatedBy], [IpAddress])
    VALUES (s.[RegionId], s.[CouncilName], 1, '127.0.0.1');
GO

/* ---------------- Seed: Villages ---------------- */
MERGE INTO [dbo].[CMS_Villages] AS t
USING (
    SELECT c.[CouncilId], s.[VillageName]
    FROM (VALUES
        (N'Gojal',    N'Gulmit'),
        (N'Gojal',    N'Passu'),
        (N'Gojal',    N'Sost'),
        (N'Aliabad',  N'Aliabad'),
        (N'Booni',    N'Booni'),
        (NULL,        N'Other')
    ) AS s ([CouncilName], [VillageName])
    LEFT JOIN [dbo].[CMS_LocalCouncils] AS c ON c.[CouncilName] = s.[CouncilName]
) AS s ([CouncilId], [VillageName])
ON t.[VillageName] = s.[VillageName]
WHEN NOT MATCHED THEN
    INSERT ([CouncilId], [VillageName], [CreatedBy], [IpAddress])
    VALUES (s.[CouncilId], s.[VillageName], 1, '127.0.0.1');
GO

/* ---- Permission catalog entries ----
   IDs are allocated dynamically (MAX+1) — never hardcode an ID
   in the >= 90000 range. */
INSERT INTO [dbo].[AllCONTROLLERS]
    ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
SELECT v.[ID], v.[CONTROLLERNAME], NULL, NULL, v.[ACTION]
FROM
(
    SELECT defs.[CONTROLLERNAME],
           defs.[ACTION],
           (SELECT ISNULL(MAX([ID]), 90051)
            FROM [dbo].[AllCONTROLLERS] WITH (UPDLOCK, HOLDLOCK)
            WHERE [ID] >= 90000)
           + ROW_NUMBER() OVER (ORDER BY defs.[CONTROLLERNAME], defs.[ACTION]) AS [ID]
    FROM (VALUES
        ('Geography', 'Read'),
        ('Geography', 'Write')
    ) AS defs ([CONTROLLERNAME], [ACTION])
) AS v
WHERE NOT EXISTS
(
    SELECT 1
    FROM [dbo].[AllCONTROLLERS] AS t
    WHERE t.[CONTROLLERNAME] = v.[CONTROLLERNAME]
      AND t.[ACTION] = v.[ACTION]
);
GO

/* ---- Grants: admin + supervisor full, frontline roles read ---- */
DECLARE @GeoRead INT, @GeoWrite INT;
SELECT @GeoRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Geography' AND [ACTION] = 'Read';
SELECT @GeoWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Geography' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @GeoRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @GeoWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @GeoRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @GeoWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @GeoRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @GeoRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @GeoRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO
