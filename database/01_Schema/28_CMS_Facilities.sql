/* ============================================================
   AKA-CMS — CMS_Facilities master table + AKHSP site seed
   Facility directory for the program (remote sites from the
   enterprise flow diagram). Additive and safe to re-run.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_Facilities]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Facilities](
        [FacilityId] INT IDENTITY(1,1) NOT NULL,
        [FacilityCode] VARCHAR(20) NOT NULL,
        [FacilityName] NVARCHAR(200) NOT NULL,
        [FacilityType] VARCHAR(50) NULL,
        [Region] NVARCHAR(100) NULL,
        [Address] NVARCHAR(500) NULL,
        [Phone] VARCHAR(20) NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_Facilities_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_Facilities_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_Facilities_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_Facilities] PRIMARY KEY CLUSTERED ([FacilityId] ASC),
        CONSTRAINT [UX_CMS_Facilities_Code] UNIQUE NONCLUSTERED ([FacilityCode] ASC)
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_Facilities_Region] ON [dbo].[CMS_Facilities] ([Region] ASC);
END
GO

/* ---- Seed: AKHSP remote sites (enterprise flow diagram) ---- */
MERGE INTO [dbo].[CMS_Facilities] AS t
USING (VALUES
    ('AKH-GILGIT',   N'AKH Gilgit',         'Hospital',           N'Gilgit',  N'Gilgit'),
    ('AKDC-JUTIAL',  N'AKDC Jutial',        'Diagnostic Centre',  N'Gilgit',  N'Jutial, Gilgit'),
    ('AKDC-GAHKUCH', N'AKDC Gahkuch',       'Diagnostic Centre',  N'Ghizer',  N'Gahkuch, Ghizer'),
    ('EFHC-ALIABAD', N'EFHC Aliabad',       'Health Centre',      N'Hunza',   N'Aliabad, Hunza'),
    ('SMC-SINGAL',   N'Singal Medical Centre', 'Medical Centre',  N'Gilgit',  N'Singal, Gilgit'),
    ('AKMC-BOONI',   N'AKMC Booni',         'Medical Centre',     N'Chitral', N'Booni, Upper Chitral'),
    ('AKDC-CHITRAL', N'AKDC Chitral',       'Diagnostic Centre',  N'Chitral', N'Chitral'),
    ('RHC-SHAGRAM',  N'RHC Shagram',        'Health Centre',      N'Chitral', N'Shagram, Chitral')
) AS s ([FacilityCode], [FacilityName], [FacilityType], [Region], [Address])
ON t.[FacilityCode] = s.[FacilityCode]
WHEN NOT MATCHED THEN
    INSERT ([FacilityCode], [FacilityName], [FacilityType], [Region], [Address], [CreatedBy], [IpAddress])
    VALUES (s.[FacilityCode], s.[FacilityName], s.[FacilityType], s.[Region], s.[Address], 1, '127.0.0.1');
GO

/* ---- Permission catalog entries ----
   IDs are allocated dynamically (MAX+1), like the Sprint9 seed —
   never hardcode an ID in the >= 90000 range. */
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
        ('Facilities', 'Read'),
        ('Facilities', 'Write')
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

/* ---- Grants: admin full, supervisor write, frontline roles read ----
   Resolved by (CONTROLLERNAME, ACTION) so re-runs stay idempotent. */
DECLARE @FacRead INT, @FacWrite INT;
SELECT @FacRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Facilities' AND [ACTION] = 'Read';
SELECT @FacWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Facilities' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @FacRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @FacWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @FacRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @FacWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @FacRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @FacRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @FacRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO
