/* ============================================================
   AKA-CMS — Sprint 8 schema (Notifications, Attachments, Audit, Sync).
   New tables only; extends CMS_Notifications in place. Never alters
   existing CO-HIS tables.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Extend CMS_Notifications with read tracking, delivery status
        and a push-ready payload field (never sent from the API). ---- */
IF COL_LENGTH(N'[dbo].[CMS_Notifications]', N'ReadAt') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_Notifications]
        ADD [ReadAt] DATETIME2 NULL;
END
GO

IF COL_LENGTH(N'[dbo].[CMS_Notifications]', N'Status') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_Notifications]
        ADD [Status] VARCHAR(20) NOT NULL
            CONSTRAINT [DF_CMS_Notifications_Status] DEFAULT ('Unread');
END
GO

IF COL_LENGTH(N'[dbo].[CMS_Notifications]', N'PushPayload') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_Notifications]
        ADD [PushPayload] NVARCHAR(MAX) NULL;
END
GO

/* Keep Status consistent with the legacy IsRead flag. */
UPDATE [dbo].[CMS_Notifications]
SET [Status] = CASE WHEN [IsRead] = 1 THEN 'Read' ELSE 'Unread' END
WHERE [Status] = 'Unread' AND [IsRead] = 1;
GO

/* ---- CMS_CaseAttachments: metadata only; the file bytes live on
        local disk under FileStorage:UploadsPath. ---- */
IF OBJECT_ID(N'[dbo].[CMS_CaseAttachments]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseAttachments](
        [AttachmentId]  INT            IDENTITY(1,1) NOT NULL,
        [CaseId]        INT            NOT NULL,
        [FileName]      NVARCHAR(260)  NOT NULL,
        [ContentType]   VARCHAR(120)   NOT NULL,
        [FileSizeBytes] BIGINT         NOT NULL,
        [StoragePath]   NVARCHAR(500)  NOT NULL,
        [UploadedBy]    INT            NULL,
        [UploadedAt]    DATETIME2      NOT NULL CONSTRAINT [DF_CMS_CaseAttachments_UploadedAt] DEFAULT (SYSUTCDATETIME()),
        [RowVersion]    ROWVERSION     NOT NULL,
        [CreatedAt]     DATETIME2      NOT NULL CONSTRAINT [DF_CMS_CaseAttachments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IsActive]      BIT            NOT NULL CONSTRAINT [DF_CMS_CaseAttachments_Active] DEFAULT (1),
        CONSTRAINT [PK_CMS_CaseAttachments] PRIMARY KEY CLUSTERED ([AttachmentId] ASC),
        CONSTRAINT [FK_CMS_CaseAttachments_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases] ([CaseId])
    );
    CREATE INDEX [IX_CMS_CaseAttachments_Case] ON [dbo].[CMS_CaseAttachments]([CaseId]);
END
GO

/* ---- CMS_SyncOutbox: offline outbox for the Flutter app.
        Server-wins on conflict; the mobile re-fetches via /api/sync/pull. ---- */
IF OBJECT_ID(N'[dbo].[CMS_SyncOutbox]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_SyncOutbox](
        [Id]              INT            IDENTITY(1,1) NOT NULL,
        [IdempotencyKey]  VARCHAR(100)   NOT NULL,
        [DeviceId]        VARCHAR(100)   NOT NULL,
        [EntityType]      VARCHAR(100)   NOT NULL, -- e.g. CMS_Cases
        [EntityId]        INT            NULL,
        [Action]          VARCHAR(20)    NOT NULL, -- CREATE / UPDATE / DELETE
        [PayloadJson]     NVARCHAR(MAX)  NOT NULL,
        [Status]          VARCHAR(20)    NOT NULL
            CONSTRAINT [DF_CMS_SyncOutbox_Status] DEFAULT ('Pending'),
        [PerformedBy]     INT            NULL,
        [CreatedAt]       DATETIME2      NOT NULL CONSTRAINT [DF_CMS_SyncOutbox_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ProcessedAt]     DATETIME2      NULL,
        [AcknowledgedAt]  DATETIME2      NULL,
        CONSTRAINT [PK_CMS_SyncOutbox] PRIMARY KEY CLUSTERED ([Id] ASC),
        CONSTRAINT [UX_CMS_SyncOutbox_IdempotencyKey] UNIQUE ([IdempotencyKey]),
        CONSTRAINT [CK_CMS_SyncOutbox_Status]
            CHECK ([Status] IN ('Pending', 'Applied', 'Conflict', 'Acked')),
        CONSTRAINT [CK_CMS_SyncOutbox_Action]
            CHECK ([Action] IN ('CREATE', 'UPDATE', 'DELETE'))
    );
    CREATE INDEX [IX_CMS_SyncOutbox_Device] ON [dbo].[CMS_SyncOutbox]([DeviceId], [CreatedAt]);
END
GO
