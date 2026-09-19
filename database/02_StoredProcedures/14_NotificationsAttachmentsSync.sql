/* ============================================================================
   AKA-CMS — Sprint 8 (Notifications, Attachments, Audit, Sync)
   Stored procedures. One proc per repository method; TRY/CATCH +
   transactions + CMS_AuditLogs on every write.

   Error-number contract (project-wide):
     50005 - row-version mismatch (optimistic concurrency)
     50008 - entity not found
     50009 - domain validation failure (400)
     50010 - invalid domain value (400)
     50011 - duplicate/conflict (409)

   Sync contract (the API contract the Flutter developer builds against):
     POST /api/sync/push  — idempotent via client-generated
       IdempotencyKey. A duplicate key returns the existing outbox
       record with a 409 (documented; the client treats 409 as
       "already processed", never retries with a new key).
     GET /api/sync/pull?since=ISO8601 — server changes since the
       watermark, derived from CMS_AuditLogs (audit-log-derived,
       kept simple; no separate server-changes table).
     POST /api/sync/ack   — acknowledges applied outbox entries.
     Conflict strategy: server-wins. If the server changed the same
       entity after the client's base version, the push is recorded
       with Status='Conflict' and the response carries the latest
       server-side change as the conflict report; the mobile must
       re-fetch via pull and reconcile locally.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_SystemSetting_Get ----
   Single setting lookup; used by the API layer to pre-validate uploads
   before the file touches disk (the upload proc validates again). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SystemSetting_Get]
    @SettingKey VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [SettingKey] AS [Key],
           [SettingValue] AS [Value]
    FROM [dbo].[CMS_SystemSettings]
    WHERE [SettingKey] = @SettingKey;
END
GO

/* ---- sp_CMS_Notification_Create ----
   Creates a notification for a user, a role, or broadcast (both NULL).
   The API stores a push-ready payload (PushPayload) but never sends
   actual pushes — the mobile reads /api/sync/pull. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Notification_Create]
    @RecipientRole    VARCHAR(60)    = NULL,
    @RecipientUserId  INT            = NULL,
    @Title            NVARCHAR(200),
    @Body             NVARCHAR(MAX),
    @RelatedCaseId    INT            = NULL,
    @RelatedEntity    VARCHAR(60)    = NULL,
    @RelatedEntityId  INT            = NULL,
    @PushPayload      NVARCHAR(MAX)  = NULL,
    @CreatedBy        INT,
    @NewNotificationId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
            THROW 50009, 'Notification title is required.', 1;
        IF @Body IS NULL OR LTRIM(RTRIM(@Body)) = ''
            THROW 50009, 'Notification body is required.', 1;
        IF @RelatedCaseId IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases]
                            WHERE [CaseId] = @RelatedCaseId AND [IsActive] = 1)
            THROW 50008, 'Case not found.', 1;

        INSERT INTO [dbo].[CMS_Notifications]
            ([RecipientRole], [RecipientUserId], [Title], [Body],
             [RelatedCaseId], [RelatedEntity], [RelatedEntityId],
             [Status], [PushPayload])
        VALUES
            (@RecipientRole, @RecipientUserId, @Title, @Body,
             @RelatedCaseId, @RelatedEntity, @RelatedEntityId,
             'Unread', @PushPayload);

        SET @NewNotificationId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Notifications', CAST(@NewNotificationId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                'Notification created for ' + COALESCE('user ' + CAST(@RecipientUserId AS VARCHAR(20)),
                                                      'role ' + COALESCE(@RecipientRole, 'broadcast')));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Notification_GetByUser ----
   Notifications visible to a user: direct, role-based, or broadcast. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Notification_GetByUser]
    @UserId     INT,
    @UnreadOnly BIT           = 0,
    @Page       INT           = 1,
    @PageSize   INT           = 20,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 100 SET @PageSize = 100;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 100 SET @PageSize = 100;

    ;WITH [Roles] AS (
        SELECT DISTINCT R.[DESCRIPTION] AS [RoleName]
        FROM [dbo].[USER_ROLE] UR
        INNER JOIN [dbo].[ROLES] R ON R.[ROLEID] = UR.[ROLEID]
        WHERE UR.[USERID] = @UserId
          AND UR.[ACTIVE] = 1
          AND R.[ACTIVE] = 1
    )
    SELECT @TotalCount = COUNT(*)
    FROM [dbo].[CMS_Notifications] N
    WHERE N.[IsActive] = 1
      AND (N.[RecipientUserId] = @UserId
           OR (N.[RecipientUserId] IS NULL AND N.[RecipientRole] IS NULL)
           OR EXISTS (SELECT 1 FROM [Roles] R WHERE R.[RoleName] = N.[RecipientRole]))
      AND (@UnreadOnly = 0 OR N.[Status] = 'Unread');

    ;WITH [Roles] AS (
        SELECT DISTINCT R.[DESCRIPTION] AS [RoleName]
        FROM [dbo].[USER_ROLE] UR
        INNER JOIN [dbo].[ROLES] R ON R.[ROLEID] = UR.[ROLEID]
        WHERE UR.[USERID] = @UserId
          AND UR.[ACTIVE] = 1
          AND R.[ACTIVE] = 1
    )
    SELECT [NotificationId], [RecipientRole], [RecipientUserId], [Title], [Body],
           [RelatedCaseId], [RelatedEntity], [RelatedEntityId],
           [IsRead], [ReadAt], [Status], [PushPayload], [CreatedAt]
    FROM [dbo].[CMS_Notifications] N
    WHERE N.[IsActive] = 1
      AND (N.[RecipientUserId] = @UserId
           OR (N.[RecipientUserId] IS NULL AND N.[RecipientRole] IS NULL)
           OR EXISTS (SELECT 1 FROM [Roles] R WHERE R.[RoleName] = N.[RecipientRole]))
      AND (@UnreadOnly = 0 OR N.[Status] = 'Unread')
    ORDER BY N.[CreatedAt] DESC, N.[NotificationId] DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---- sp_CMS_Notification_MarkAsRead ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Notification_MarkAsRead]
    @NotificationId INT,
    @UserId         INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Notifications]
                       WHERE [NotificationId] = @NotificationId
                         AND [IsActive] = 1
                         AND ([RecipientUserId] = @UserId
                              OR ([RecipientUserId] IS NULL AND [RecipientRole] IS NULL)
                              OR EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] UR
                                         INNER JOIN [dbo].[ROLES] R ON R.[ROLEID] = UR.[ROLEID]
                                         WHERE UR.[USERID] = @UserId
                                           AND UR.[ACTIVE] = 1
                                           AND R.[ACTIVE] = 1
                                           AND R.[DESCRIPTION] = [CMS_Notifications].[RecipientRole])))
            THROW 50008, 'Notification not found.', 1;

        UPDATE [dbo].[CMS_Notifications]
        SET [IsRead] = 1,
            [Status] = 'Read',
            [ReadAt] = COALESCE([ReadAt], SYSUTCDATETIME())
        WHERE [NotificationId] = @NotificationId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Notifications', CAST(@NotificationId AS VARCHAR(50)), 'UPDATE', @UserId,
                'Notification marked as read.');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Notification_MarkAllRead ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Notification_MarkAllRead]
    @UserId       INT,
    @MarkedCount  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE N
        SET [IsRead] = 1,
            [Status] = 'Read',
            [ReadAt] = COALESCE(N.[ReadAt], SYSUTCDATETIME())
        FROM [dbo].[CMS_Notifications] N
        WHERE N.[IsActive] = 1
          AND N.[Status] = 'Unread'
          AND (N.[RecipientUserId] = @UserId
               OR (N.[RecipientUserId] IS NULL AND N.[RecipientRole] IS NULL)
               OR EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] UR
                          INNER JOIN [dbo].[ROLES] R ON R.[ROLEID] = UR.[ROLEID]
                          WHERE UR.[USERID] = @UserId
                            AND UR.[ACTIVE] = 1
                            AND R.[ACTIVE] = 1
                            AND R.[DESCRIPTION] = N.[RecipientRole]));

        SET @MarkedCount = @@ROWCOUNT;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Notifications', CAST(@UserId AS VARCHAR(50)), 'UPDATE', @UserId,
                'All notifications marked as read (' + CAST(@MarkedCount AS VARCHAR(20)) + ').');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseAttachment_Upload ----
   Persists attachment metadata; the API has already written the file to
   disk under FileStorage:UploadsPath. Size/type limits are enforced here
   from CMS_SystemSettings (provisional client-unconfirmed values). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseAttachment_Upload]
    @CaseId          INT,
    @FileName        NVARCHAR(260),
    @ContentType     VARCHAR(120),
    @FileSizeBytes   BIGINT,
    @StoragePath     NVARCHAR(500),
    @UploadedBy      INT,
    @NewAttachmentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases]
                       WHERE [CaseId] = @CaseId AND [IsActive] = 1)
            THROW 50008, 'Case not found.', 1;
        IF @FileName IS NULL OR LTRIM(RTRIM(@FileName)) = ''
            THROW 50009, 'FileName is required.', 1;
        IF @FileSizeBytes IS NULL OR @FileSizeBytes <= 0
            THROW 50009, 'FileSizeBytes must be positive.', 1;

        DECLARE @MaxBytes BIGINT, @AllowedTypes NVARCHAR(500), @Extension NVARCHAR(20);
        SELECT @MaxBytes = TRY_CAST([SettingValue] AS BIGINT)
        FROM [dbo].[CMS_SystemSettings]
        WHERE [SettingKey] = 'Attachments.MaxAttachmentBytes';
        SELECT @AllowedTypes = LOWER([SettingValue])
        FROM [dbo].[CMS_SystemSettings]
        WHERE [SettingKey] = 'Attachments.AllowedAttachmentTypes';

        SET @Extension = LOWER(RIGHT(@FileName, CHARINDEX('.', REVERSE(@FileName)) - 1));

        IF @MaxBytes IS NOT NULL AND @FileSizeBytes > @MaxBytes
            THROW 50009, 'Attachment exceeds the maximum allowed size.', 1;
        IF @AllowedTypes IS NOT NULL
           AND (',' + @AllowedTypes + ',' NOT LIKE '%,' + @Extension + ',%')
            THROW 50009, 'Attachment type is not allowed.', 1;

        INSERT INTO [dbo].[CMS_CaseAttachments]
            ([CaseId], [FileName], [ContentType], [FileSizeBytes],
             [StoragePath], [UploadedBy])
        VALUES
            (@CaseId, @FileName, @ContentType, @FileSizeBytes,
             @StoragePath, @UploadedBy);

        SET @NewAttachmentId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseAttachments', CAST(@NewAttachmentId AS VARCHAR(50)), 'INSERT', @UploadedBy,
                'Attachment "' + LEFT(@FileName, 200) + '" uploaded for case ' + CAST(@CaseId AS VARCHAR(20)) + '.');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseAttachment_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseAttachment_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases]
                   WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT [AttachmentId], [CaseId], [FileName], [ContentType],
           [FileSizeBytes], [StoragePath], [UploadedBy], [UploadedAt],
           [CreatedAt]
    FROM [dbo].[CMS_CaseAttachments]
    WHERE [CaseId] = @CaseId AND [IsActive] = 1
    ORDER BY [UploadedAt] DESC;
END
GO

/* ---- sp_CMS_CaseAttachment_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseAttachment_GetById]
    @AttachmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_CaseAttachments]
                   WHERE [AttachmentId] = @AttachmentId AND [IsActive] = 1)
        THROW 50008, 'Attachment not found.', 1;

    SELECT [AttachmentId], [CaseId], [FileName], [ContentType],
           [FileSizeBytes], [StoragePath], [UploadedBy], [UploadedAt],
           [CreatedAt]
    FROM [dbo].[CMS_CaseAttachments]
    WHERE [AttachmentId] = @AttachmentId AND [IsActive] = 1;
END
GO

/* ---- sp_CMS_AuditLog_Query ----
   Read-only filtered query over CMS_AuditLogs; never writes. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_AuditLog_Query]
    @TableName   VARCHAR(100) = NULL,
    @RecordId    VARCHAR(50)  = NULL,
    @PerformedBy INT          = NULL,
    @FromDate    DATETIME2    = NULL,
    @ToDate      DATETIME2    = NULL,
    @Page        INT          = 1,
    @PageSize    INT          = 20,
    @TotalCount  BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 20;
    IF @PageSize > 100 SET @PageSize = 100;

    SELECT @TotalCount = COUNT(*)
    FROM [dbo].[CMS_AuditLogs]
    WHERE (@TableName IS NULL OR [TableName] = @TableName)
      AND (@RecordId IS NULL OR [RecordId] = @RecordId)
      AND (@PerformedBy IS NULL OR [PerformedBy] = @PerformedBy)
      AND (@FromDate IS NULL OR [PerformedAt] >= @FromDate)
      AND (@ToDate IS NULL OR [PerformedAt] <= @ToDate);

    SELECT [Id], [TableName], [RecordId], [Action],
           [PerformedBy], [PerformedAt], [Details]
    FROM [dbo].[CMS_AuditLogs]
    WHERE (@TableName IS NULL OR [TableName] = @TableName)
      AND (@RecordId IS NULL OR [RecordId] = @RecordId)
      AND (@PerformedBy IS NULL OR [PerformedBy] = @PerformedBy)
      AND (@FromDate IS NULL OR [PerformedAt] >= @FromDate)
      AND (@ToDate IS NULL OR [PerformedAt] <= @ToDate)
    ORDER BY [PerformedAt] DESC, [Id] DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---- sp_CMS_SyncOutbox_Push ----
   Records an offline operation from the Flutter app. Idempotent on
   IdempotencyKey: a duplicate key never inserts a second row — the
   existing record is returned and the API responds 409.
   Conflict detection (server-wins): if the client supplied BaseVersion
   and the server changed the same entity afterwards, the push is kept
   with Status='Conflict' and the latest server-side change is returned
   as the conflict report instead of being applied. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SyncOutbox_Push]
    @IdempotencyKey VARCHAR(100),
    @DeviceId       VARCHAR(100),
    @EntityType     VARCHAR(100),
    @EntityId       INT            = NULL,
    @Action         VARCHAR(20),
    @PayloadJson    NVARCHAR(MAX),
    @BaseVersion    DATETIME2      = NULL,
    @PerformedBy    INT,
    @OutboxId       INT OUTPUT,
    @Status         VARCHAR(20) OUTPUT,
    @IsDuplicate    BIT OUTPUT,
    @ConflictReport NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @IdempotencyKey IS NULL OR LTRIM(RTRIM(@IdempotencyKey)) = ''
            THROW 50009, 'IdempotencyKey is required.', 1;
        IF @DeviceId IS NULL OR LTRIM(RTRIM(@DeviceId)) = ''
            THROW 50009, 'DeviceId is required.', 1;
        IF @EntityType IS NULL OR LTRIM(RTRIM(@EntityType)) = ''
            THROW 50009, 'EntityType is required.', 1;
        IF @Action NOT IN ('CREATE', 'UPDATE', 'DELETE')
            THROW 50010, 'Action must be CREATE, UPDATE or DELETE.', 1;
        IF @PayloadJson IS NULL
            THROW 50009, 'PayloadJson is required.', 1;

        SELECT @OutboxId = [Id], @Status = [Status]
        FROM [dbo].[CMS_SyncOutbox]
        WHERE [IdempotencyKey] = @IdempotencyKey;

        IF @OutboxId IS NOT NULL
        BEGIN
            SET @IsDuplicate = 1;
            SET @ConflictReport = NULL;
        END
        ELSE
        BEGIN
            SET @IsDuplicate = 0;
            SET @Status = 'Applied';

            /* Server-wins conflict check against the audit trail. */
            IF @BaseVersion IS NOT NULL AND @EntityId IS NOT NULL
               AND EXISTS (SELECT 1 FROM [dbo].[CMS_AuditLogs]
                           WHERE [TableName] = @EntityType
                             AND [RecordId] = CAST(@EntityId AS VARCHAR(50))
                             AND [PerformedAt] > @BaseVersion)
            BEGIN
                SET @Status = 'Conflict';
                SELECT @ConflictReport = (
                    SELECT TOP (1)
                           [TableName] AS [entityType],
                           [RecordId]  AS [entityId],
                           [Action]    AS [serverAction],
                           [PerformedAt] AS [serverChangedAt],
                           [PerformedBy] AS [serverChangedBy],
                           [Details]   AS [serverDetails]
                    FROM [dbo].[CMS_AuditLogs]
                    WHERE [TableName] = @EntityType
                      AND [RecordId] = CAST(@EntityId AS VARCHAR(50))
                      AND [PerformedAt] > @BaseVersion
                    ORDER BY [PerformedAt] DESC
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            END

            INSERT INTO [dbo].[CMS_SyncOutbox]
                ([IdempotencyKey], [DeviceId], [EntityType], [EntityId],
                 [Action], [PayloadJson], [Status], [PerformedBy],
                 [ProcessedAt])
            VALUES
                (@IdempotencyKey, @DeviceId, @EntityType, @EntityId,
                 @Action, @PayloadJson, @Status, @PerformedBy,
                 CASE WHEN @Status = 'Applied' THEN SYSUTCDATETIME() END);

            SET @OutboxId = SCOPE_IDENTITY();

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_SyncOutbox', CAST(@OutboxId AS VARCHAR(50)), 'INSERT', @PerformedBy,
                    'Sync push ' + @Action + ' ' + @EntityType + ' from device ' + @DeviceId
                    + ' -> ' + @Status + '.');
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Sync_Pull ----
   Server changes since the watermark, derived from CMS_AuditLogs. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Sync_Pull]
    @Since       DATETIME2,
    @Page        INT          = 1,
    @PageSize    INT          = 100,
    @TotalCount  BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Since IS NULL
        THROW 50009, 'The since watermark is required.', 1;
    IF @Page < 1 SET @Page = 1;
    IF @PageSize < 1 SET @PageSize = 100;
    IF @PageSize > 500 SET @PageSize = 500;

    SELECT @TotalCount = COUNT(*)
    FROM [dbo].[CMS_AuditLogs]
    WHERE [PerformedAt] > @Since;

    SELECT [Id] AS [ChangeId],
           [TableName] AS [EntityType],
           [RecordId] AS [EntityId],
           [Action],
           [PerformedBy],
           [PerformedAt] AS [ChangedAt],
           [Details]
    FROM [dbo].[CMS_AuditLogs]
    WHERE [PerformedAt] > @Since
    ORDER BY [PerformedAt] ASC, [Id] ASC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

/* ---- sp_CMS_SyncOutbox_Ack ----
   Acknowledges a processed outbox entry so the device can drop it. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SyncOutbox_Ack]
    @IdempotencyKey VARCHAR(100),
    @DeviceId       VARCHAR(100),
    @PerformedBy    INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_SyncOutbox]
                       WHERE [IdempotencyKey] = @IdempotencyKey
                         AND [DeviceId] = @DeviceId)
            THROW 50008, 'Sync outbox entry not found.', 1;

        UPDATE [dbo].[CMS_SyncOutbox]
        SET [Status] = 'Acked',
            [AcknowledgedAt] = SYSUTCDATETIME()
        WHERE [IdempotencyKey] = @IdempotencyKey
          AND [DeviceId] = @DeviceId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_SyncOutbox', @IdempotencyKey, 'UPDATE', @PerformedBy,
                'Sync outbox entry acknowledged by device ' + @DeviceId + '.');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
