/* ============================================================
   AKA-CMS — Patient identity tables (04)
   New tables only. Never alters existing CO-HIS tables.

   Patient identity findings in CO-HIS:
   - No central patient master/demographics table exists.
   - MRNO (varchar) is the identity key, spread across PAT_ENCTR
     (the encounter registry), ADMISSION, MR_MENTALHEALTH,
     MR_SCREENING and other transaction tables.
   - UNIT (CODE, NAME, FACILITYTYPE, ...) is the facility table.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_CommunityMembers]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CommunityMembers](
        [MemberId] INT IDENTITY(1,1) NOT NULL,
        [MrNo] VARCHAR(20) NULL,
        [FullName] NVARCHAR(200) NOT NULL,
        [FatherName] NVARCHAR(200) NULL,
        [Gender] VARCHAR(10) NULL,
        [DateOfBirth] DATE NULL,
        [Cnic] VARCHAR(15) NULL,
        [Phone] VARCHAR(20) NULL,
        [Address] NVARCHAR(500) NULL,
        [UnionCouncilCode] VARCHAR(20) NULL,
        [VillageCode] VARCHAR(20) NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_CommunityMembers_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_CommunityMembers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_CommunityMembers_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_CommunityMembers] PRIMARY KEY CLUSTERED ([MemberId] ASC)
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_CommunityMembers_MrNo] ON [dbo].[CMS_CommunityMembers] ([MrNo] ASC);
    CREATE NONCLUSTERED INDEX [IX_CMS_CommunityMembers_Cnic] ON [dbo].[CMS_CommunityMembers] ([Cnic] ASC);
END
GO

IF OBJECT_ID(N'[dbo].[CMS_HisMrMappings]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_HisMrMappings](
        [MappingId] INT IDENTITY(1,1) NOT NULL,
        [CommunityMemberId] INT NULL,
        [MrNo] VARCHAR(20) NOT NULL,
        [IsDummy] BIT NOT NULL CONSTRAINT [DF_CMS_HisMrMappings_IsDummy] DEFAULT (0),
        [UnitCode] INT NOT NULL,
        [ResolvedMrNo] VARCHAR(20) NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_HisMrMappings_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_HisMrMappings_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_HisMrMappings_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_HisMrMappings] PRIMARY KEY CLUSTERED ([MappingId] ASC),
        CONSTRAINT [FK_CMS_HisMrMappings_CommunityMembers] FOREIGN KEY ([CommunityMemberId])
            REFERENCES [dbo].[CMS_CommunityMembers] ([MemberId])
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CMS_HisMrMappings_MrNo_Unit]
        ON [dbo].[CMS_HisMrMappings] ([MrNo] ASC, [UnitCode] ASC)
        WHERE [IsActive] = 1;
END
GO

IF OBJECT_ID(N'[dbo].[CMS_FacilityMrBlocks]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_FacilityMrBlocks](
        [FacilityMrBlockId] INT IDENTITY(1,1) NOT NULL,
        [UnitCode] INT NOT NULL,
        [MrPrefix] VARCHAR(10) NOT NULL,
        [BlockStart] INT NOT NULL,
        [BlockEnd] INT NOT NULL,
        [NextSequence] INT NOT NULL,
        [IsPlaceholder] BIT NOT NULL CONSTRAINT [DF_CMS_FacilityMrBlocks_IsPlaceholder] DEFAULT (1),
        [IsActive] BIT NOT NULL CONSTRAINT [DF_CMS_FacilityMrBlocks_IsActive] DEFAULT (1),
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_FacilityMrBlocks_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_FacilityMrBlocks] PRIMARY KEY CLUSTERED ([FacilityMrBlockId] ASC),
        CONSTRAINT [CK_CMS_FacilityMrBlocks_Range] CHECK ([BlockEnd] >= [BlockStart] AND [NextSequence] >= [BlockStart])
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CMS_FacilityMrBlocks_Unit]
        ON [dbo].[CMS_FacilityMrBlocks] ([UnitCode] ASC)
        WHERE [IsActive] = 1;
END
GO
