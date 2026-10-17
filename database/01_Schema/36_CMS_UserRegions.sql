/* ============================================================================
   36_CMS_UserRegions.sql
   Users can belong to multiple regions: CMS_UserRegions (UserId, RegionName).
   Migrates the single CMS_UserSettings.Region value into the new table.
   Idempotent: safe to re-run.
   ============================================================================ */

IF OBJECT_ID(N'[dbo].[CMS_UserRegions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_UserRegions] (
        [UserRegionId] INT IDENTITY(1,1) NOT NULL,
        [UserId]       INT NOT NULL,
        [RegionName]   NVARCHAR(100) NOT NULL,
        [CreatedAt]    DATETIME2 NOT NULL CONSTRAINT [DF_CMS_UserRegions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_CMS_UserRegions] PRIMARY KEY CLUSTERED ([UserRegionId]),
        CONSTRAINT [UQ_CMS_UserRegions_User_Region] UNIQUE NONCLUSTERED ([UserId], [RegionName])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_UserRegions_UserId]
        ON [dbo].[CMS_UserRegions] ([UserId]);
END
GO

-- Migrate existing single-region values.
INSERT INTO [dbo].[CMS_UserRegions] ([UserId], [RegionName])
SELECT [UserId], [Region]
FROM [dbo].[CMS_UserSettings]
WHERE [Region] IS NOT NULL AND LTRIM(RTRIM([Region])) <> ''
  AND NOT EXISTS (
      SELECT 1 FROM [dbo].[CMS_UserRegions] ur
      WHERE ur.[UserId] = [CMS_UserSettings].[UserId]
        AND ur.[RegionName] = [CMS_UserSettings].[Region]);
GO
