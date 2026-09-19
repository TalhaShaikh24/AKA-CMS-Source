namespace AKA.CMS.Application.DTOs;

public sealed record LostToFollowUpDto(
    int LtfuId,
    int CaseId,
    int MissedCount,
    DateTime? LastContactDate,
    DateTime? LtfuDeclaredDate,
    string Status,
    string? ReEngagementNotes,
    byte[] RowVersion,
    DateTime CreatedAt);

public sealed record EvaluateLtfuResponse(
    LostToFollowUpDto Tracking,
    bool Declared,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);

public sealed record ReEngageLtfuRequest(
    string ReEngagementNotes);

public sealed record ReEngageLtfuResponse(
    LostToFollowUpDto Tracking,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);
