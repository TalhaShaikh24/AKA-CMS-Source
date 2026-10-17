/* ============================================================================
   26_CaseLogRevised.sql
   Case Log Revised (DHRC 210926) — stored procedures
   - sp_CMS_CommunityMember_Create: new params (FirstName/LastName/DateOfCall/
     EntryPoint/ReturningCaller/ConsentToProceed)
   - sp_CMS_CommunityMember_GetById: returns new columns
   - sp_CMS_RiskAssessment_Save: upsert risk assessment for a case
   - sp_CMS_RiskAssessment_GetByCase: latest assessment for a case
   ============================================================================ */

/* ---- sp_CMS_CommunityMember_Create (extended) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CommunityMember_Create]
    @FullName NVARCHAR(200),
    @FatherName NVARCHAR(200) = NULL,
    @Gender VARCHAR(10) = NULL,
    @DateOfBirth DATE = NULL,
    @Cnic VARCHAR(15) = NULL,
    @Phone VARCHAR(20) = NULL,
    @Address NVARCHAR(500) = NULL,
    @UnionCouncilCode VARCHAR(20) = NULL,
    @VillageCode VARCHAR(20) = NULL,
    @MrNo VARCHAR(20) = NULL,
    @Age INT = NULL,
    @RegionCouncil NVARCHAR(100) = NULL,
    @LocalCouncil NVARCHAR(100) = NULL,
    @Village NVARCHAR(100) = NULL,
    @JkAttend NVARCHAR(100) = NULL,
    @EmploymentEducation NVARCHAR(200) = NULL,
    @MaritalStatus VARCHAR(30) = NULL,
    @NumberOfChildren INT = NULL,
    @LanguagesSpoken NVARCHAR(200) = NULL,
    @HealthInsurance VARCHAR(50) = NULL,
    @GpUsualCare NVARCHAR(200) = NULL,
    @PriorMhTreatment VARCHAR(50) = NULL,
    @ConnectedToMhCare VARCHAR(50) = NULL,
    @CareProviderName NVARCHAR(200) = NULL,
    @FirstName NVARCHAR(100) = NULL,
    @LastName NVARCHAR(100) = NULL,
    @DateOfCall DATE = NULL,
    @EntryPoint VARCHAR(50) = NULL,
    @ReturningCaller VARCHAR(50) = NULL,
    @ConsentToProceed VARCHAR(50) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewMemberId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_CommunityMembers]
            ([MrNo], [FullName], [FatherName], [Gender], [DateOfBirth], [Cnic], [Phone],
             [Address], [UnionCouncilCode], [VillageCode], [Age], [RegionCouncil],
             [LocalCouncil], [Village], [JkAttend], [EmploymentEducation], [MaritalStatus],
             [NumberOfChildren], [LanguagesSpoken], [HealthInsurance], [GpUsualCare],
             [PriorMhTreatment], [ConnectedToMhCare], [CareProviderName],
             [FirstName], [LastName], [DateOfCall], [EntryPoint], [ReturningCaller], [ConsentToProceed],
             [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@MrNo, @FullName, @FatherName, @Gender, @DateOfBirth, @Cnic, @Phone,
             @Address, @UnionCouncilCode, @VillageCode, @Age, @RegionCouncil,
             @LocalCouncil, @Village, @JkAttend, @EmploymentEducation, @MaritalStatus,
             @NumberOfChildren, @LanguagesSpoken, @HealthInsurance, @GpUsualCare,
             @PriorMhTreatment, @ConnectedToMhCare, @CareProviderName,
             @FirstName, @LastName, @DateOfCall, @EntryPoint, @ReturningCaller, @ConsentToProceed,
             1, @CreatedBy, @IpAddress);

        SET @NewMemberId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CommunityMembers', CAST(@NewMemberId AS VARCHAR(50)), 'INSERT', @CreatedBy, @FullName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CommunityMember_GetById (extended) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CommunityMember_GetById]
    @MemberId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [MemberId],
            [MrNo],
            [FullName],
            [FirstName],
            [LastName],
            [FatherName],
            [Gender],
            [DateOfBirth],
            [Cnic],
            [Phone],
            [Address],
            [UnionCouncilCode],
            [VillageCode],
            [Age],
            [RegionCouncil],
            [LocalCouncil],
            [Village],
            [JkAttend],
            [EmploymentEducation],
            [MaritalStatus],
            [NumberOfChildren],
            [LanguagesSpoken],
            [HealthInsurance],
            [GpUsualCare],
            [PriorMhTreatment],
            [ConnectedToMhCare],
            [CareProviderName],
            [DateOfCall],
            [EntryPoint],
            [ReturningCaller],
            [ConsentToProceed],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_CommunityMembers]
    WHERE [MemberId] = @MemberId;
END
GO

/* ---- sp_CMS_RiskAssessment_Save (upsert by CaseId) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_RiskAssessment_Save]
    @CaseId INT,
    @PresentingConcern NVARCHAR(2000) = NULL,
    @PrimaryMhIssue VARCHAR(100) = NULL,
    @PrimaryMhIssueOther NVARCHAR(200) = NULL,
    @IsCrisis VARCHAR(50) = NULL,
    @CrisisType VARCHAR(50) = NULL,
    @RiskCategory VARCHAR(30) = NULL,
    @SuicidalIdeation VARCHAR(60) = NULL,
    @SelfHarmRisk VARCHAR(30) = NULL,
    @ViolenceRisk VARCHAR(30) = NULL,
    @SeverityImmediacy VARCHAR(50) = NULL,
    @AccessToMeans VARCHAR(20) = NULL,
    @SafeguardingConcerns NVARCHAR(1000) = NULL,
    @PreviousAttempts NVARCHAR(1000) = NULL,
    @CurrentSupports NVARCHAR(1000) = NULL,
    @ProtectiveFactors NVARCHAR(1000) = NULL,
    @BarriersToCare NVARCHAR(1000) = NULL,
    @SafetyPlanFilled VARCHAR(20) = NULL,
    @SocialDeterminantIssues NVARCHAR(500) = NULL,
    @SocialDeterminantOther NVARCHAR(200) = NULL,
    @SupervisorNotified VARCHAR(10) = NULL,
    @SupervisorNotifiedAt DATETIME2 = NULL,
    @AssessorName NVARCHAR(200) = NULL,
    @AssessedAt DATETIME2 = NULL,
    @PerformedBy INT,
    @AssessmentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        SELECT TOP (1) @AssessmentId = [AssessmentId]
        FROM [dbo].[CMS_CaseRiskAssessments]
        WHERE [CaseId] = @CaseId
        ORDER BY [AssessmentId] DESC;

        IF @AssessmentId IS NULL
        BEGIN
            INSERT INTO [dbo].[CMS_CaseRiskAssessments]
                ([CaseId], [PresentingConcern], [PrimaryMhIssue], [PrimaryMhIssueOther],
                 [IsCrisis], [CrisisType], [RiskCategory], [SuicidalIdeation], [SelfHarmRisk],
                 [ViolenceRisk], [SeverityImmediacy], [AccessToMeans], [SafeguardingConcerns],
                 [PreviousAttempts], [CurrentSupports], [ProtectiveFactors], [BarriersToCare],
                 [SafetyPlanFilled], [SocialDeterminantIssues], [SocialDeterminantOther],
                 [SupervisorNotified], [SupervisorNotifiedAt], [AssessorName], [AssessedAt],
                 [CreatedBy])
            VALUES
                (@CaseId, @PresentingConcern, @PrimaryMhIssue, @PrimaryMhIssueOther,
                 @IsCrisis, @CrisisType, @RiskCategory, @SuicidalIdeation, @SelfHarmRisk,
                 @ViolenceRisk, @SeverityImmediacy, @AccessToMeans, @SafeguardingConcerns,
                 @PreviousAttempts, @CurrentSupports, @ProtectiveFactors, @BarriersToCare,
                 @SafetyPlanFilled, @SocialDeterminantIssues, @SocialDeterminantOther,
                 @SupervisorNotified, @SupervisorNotifiedAt, @AssessorName, @AssessedAt,
                 @PerformedBy);

            SET @AssessmentId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [dbo].[CMS_CaseRiskAssessments]
            SET [PresentingConcern] = @PresentingConcern,
                [PrimaryMhIssue] = @PrimaryMhIssue,
                [PrimaryMhIssueOther] = @PrimaryMhIssueOther,
                [IsCrisis] = @IsCrisis,
                [CrisisType] = @CrisisType,
                [RiskCategory] = @RiskCategory,
                [SuicidalIdeation] = @SuicidalIdeation,
                [SelfHarmRisk] = @SelfHarmRisk,
                [ViolenceRisk] = @ViolenceRisk,
                [SeverityImmediacy] = @SeverityImmediacy,
                [AccessToMeans] = @AccessToMeans,
                [SafeguardingConcerns] = @SafeguardingConcerns,
                [PreviousAttempts] = @PreviousAttempts,
                [CurrentSupports] = @CurrentSupports,
                [ProtectiveFactors] = @ProtectiveFactors,
                [BarriersToCare] = @BarriersToCare,
                [SafetyPlanFilled] = @SafetyPlanFilled,
                [SocialDeterminantIssues] = @SocialDeterminantIssues,
                [SocialDeterminantOther] = @SocialDeterminantOther,
                [SupervisorNotified] = @SupervisorNotified,
                [SupervisorNotifiedAt] = @SupervisorNotifiedAt,
                [AssessorName] = @AssessorName,
                [AssessedAt] = @AssessedAt,
                [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME()
            WHERE [AssessmentId] = @AssessmentId;
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_RiskAssessment_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_RiskAssessment_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
            [AssessmentId],
            [CaseId],
            [PresentingConcern],
            [PrimaryMhIssue],
            [PrimaryMhIssueOther],
            [IsCrisis],
            [CrisisType],
            [RiskCategory],
            [SuicidalIdeation],
            [SelfHarmRisk],
            [ViolenceRisk],
            [SeverityImmediacy],
            [AccessToMeans],
            [SafeguardingConcerns],
            [PreviousAttempts],
            [CurrentSupports],
            [ProtectiveFactors],
            [BarriersToCare],
            [SafetyPlanFilled],
            [SocialDeterminantIssues],
            [SocialDeterminantOther],
            [SupervisorNotified],
            [SupervisorNotifiedAt],
            [AssessorName],
            [AssessedAt],
            [CreatedBy],
            [CreatedAt]
    FROM [dbo].[CMS_CaseRiskAssessments]
    WHERE [CaseId] = @CaseId
    ORDER BY [AssessmentId] DESC;
END
GO
