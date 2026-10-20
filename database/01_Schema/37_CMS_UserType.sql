/* ============================================================================
   37_CMS_UserType.sql
   Client requirement: Active Directory users can also be added to the system.
   - USERS.[Type]: 'System' (local account) or 'AD' (Active Directory user).
     Backfilled from the existing ADUSER flag; kept for later verification
     (login source check) once real AD config is available.
   - CMS_AdDirectoryUsers: DUMMY stand-in for the real AD directory until the
     client provides AD configuration (LDAP). Replace its contents / feed it
     from a sync job later — the API contract stays the same.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.USERS', 'Type') IS NULL
    ALTER TABLE [dbo].[USERS]
        ADD [Type] VARCHAR(20) NOT NULL
            CONSTRAINT [DF_USERS_Type] DEFAULT ('System');
GO

-- Backfill from the legacy ADUSER flag (own batch: the column must exist
-- before this UPDATE compiles).
SET QUOTED_IDENTIFIER ON;
UPDATE [dbo].[USERS]
SET [Type] = CASE WHEN [ADUSER] = 1 THEN 'AD' ELSE 'System' END
WHERE [Type] <> CASE WHEN [ADUSER] = 1 THEN 'AD' ELSE 'System' END;
GO

IF OBJECT_ID(N'[dbo].[CMS_AdDirectoryUsers]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_AdDirectoryUsers] (
        [AdUserId]       INT IDENTITY(1,1) NOT NULL,
        [SamAccountName] VARCHAR(100) NOT NULL,
        [DisplayName]    NVARCHAR(200) NOT NULL,
        [Email]          VARCHAR(255) NULL,
        [Department]     NVARCHAR(100) NULL,
        [JobTitle]       NVARCHAR(100) NULL,
        [IsEnabled]      BIT NOT NULL CONSTRAINT [DF_CMS_AdDirectoryUsers_IsEnabled] DEFAULT (1),
        CONSTRAINT [PK_CMS_AdDirectoryUsers] PRIMARY KEY CLUSTERED ([AdUserId]),
        CONSTRAINT [UQ_CMS_AdDirectoryUsers_Sam] UNIQUE NONCLUSTERED ([SamAccountName])
    );

    /* ---- Dummy AD users (replace with real AD sync later) ---- */
    INSERT INTO [dbo].[CMS_AdDirectoryUsers] ([SamAccountName], [DisplayName], [Email], [Department], [JobTitle])
    VALUES
        ('ahmed.raza',     'Ahmed Raza',     'ahmed.raza@aku.edu',     'Mental Health', 'Clinical Psychologist'),
        ('fatima.noor',    'Fatima Noor',    'fatima.noor@aku.edu',    'Mental Health', 'Case Management Officer'),
        ('bilal.hussain',  'Bilal Hussain',  'bilal.hussain@aku.edu',  'Community Health', 'Field Supervisor'),
        ('sana.tariq',     'Sana Tariq',     'sana.tariq@aku.edu',     'Mental Health', 'Psychiatrist'),
        ('usman.ali',      'Usman Ali',      'usman.ali@aku.edu',      'IT Services',   'Systems Analyst'),
        ('maria.aslam',    'Maria Aslam',    'maria.aslam@aku.edu',    'Community Health', 'Awareness Coordinator'),
        ('hassan.javed',   'Hassan Javed',   'hassan.javed@aku.edu',   'Mental Health', 'Counsellor'),
        ('zainab.khan',    'Zainab Khan',    'zainab.khan@aku.edu',    'Nursing',       'Staff Nurse'),
        ('omar.farooq',    'Omar Farooq',    'omar.farooq@aku.edu',    'Administration','Programme Officer'),
        ('ayesha.siddiqui','Ayesha Siddiqui','ayesha.siddiqui@aku.edu','Mental Health', 'Social Worker');
END
GO
