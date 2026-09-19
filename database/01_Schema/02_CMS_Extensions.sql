/* ============================================================
   AKA-CMS — CMS extension tables (02)
   New tables only. Never alters existing CO-HIS tables.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_UserCredentials]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_UserCredentials](
        [UserId] INT NOT NULL,
        [PasswordHash] VARCHAR(255) NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_UserCredentials_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt] DATETIME2 NULL,
        CONSTRAINT [PK_CMS_UserCredentials] PRIMARY KEY CLUSTERED ([UserId] ASC),
        CONSTRAINT [FK_CMS_UserCredentials_USERS] FOREIGN KEY ([UserId]) REFERENCES [dbo].[USERS] ([USERID])
    );
END
GO

IF OBJECT_ID(N'[dbo].[CMS_RefreshTokens]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_RefreshTokens](
        [Id] INT IDENTITY(1,1) NOT NULL,
        [Token] VARCHAR(256) NOT NULL,
        [UserId] INT NOT NULL,
        [ExpiresAt] DATETIME2 NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_RefreshTokens_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [RevokedAt] DATETIME2 NULL,
        [ReplacedByToken] VARCHAR(256) NULL,
        CONSTRAINT [PK_CMS_RefreshTokens] PRIMARY KEY CLUSTERED ([Id] ASC),
        CONSTRAINT [FK_CMS_RefreshTokens_USERS] FOREIGN KEY ([UserId]) REFERENCES [dbo].[USERS] ([USERID])
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CMS_RefreshTokens_Token] ON [dbo].[CMS_RefreshTokens] ([Token] ASC);
END
GO

IF OBJECT_ID(N'[dbo].[CMS_AuditLogs]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_AuditLogs](
        [Id] BIGINT IDENTITY(1,1) NOT NULL,
        [TableName] VARCHAR(100) NOT NULL,
        [RecordId] VARCHAR(50) NOT NULL,
        [Action] VARCHAR(20) NOT NULL,
        [PerformedBy] INT NULL,
        [PerformedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_AuditLogs_PerformedAt] DEFAULT (SYSUTCDATETIME()),
        [Details] NVARCHAR(MAX) NULL,
        CONSTRAINT [PK_CMS_AuditLogs] PRIMARY KEY CLUSTERED ([Id] ASC)
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_AuditLogs_Table_Record] ON [dbo].[CMS_AuditLogs] ([TableName] ASC, [RecordId] ASC);
END
GO
