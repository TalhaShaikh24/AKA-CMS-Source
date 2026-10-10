/* ============================================================
   AKA-CMS — Referral queue list (across cases) for the web UI.
   Additive and safe to re-run.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Referral_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Referral_GetAll]
    @Top INT = 100
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
           r.[ReferralId], r.[ReferralNumber], r.[CaseId],
           c.[CaseNumber],
           r.[ReferredTo],
           r.[Status], r.[RejectionReason], r.[ParentReferralId],
           p.[ReferralNumber] AS [ParentReferralNumber],
           r.[SlaDueAt], r.[Notes], r.[CreatedBy],
           u.[USERNAME] AS [CreatedByUsername], r.[CreatedAt], r.[RowVersion]
    FROM [dbo].[CMS_Referrals] r
    LEFT JOIN [dbo].[CMS_Referrals] p ON p.[ReferralId] = r.[ParentReferralId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = r.[CreatedBy]
    LEFT JOIN [dbo].[CMS_Cases] c ON c.[CaseId] = r.[CaseId]
    WHERE r.[IsActive] = 1
    ORDER BY r.[ReferralId] DESC;
END
GO
