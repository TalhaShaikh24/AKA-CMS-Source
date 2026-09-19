namespace AKA.CMS.Application.DTOs;

public sealed record CaseClosureDto(
    int ClosureId,
    int CaseId,
    string ClosureReason,
    bool SymptomRemission,
    string? ClosureSummary,
    string ApprovalStatus,
    int RequestedByUserId,
    DateTime RequestedAt,
    int? ApprovedByUserId,
    DateTime? ApprovedAt,
    string? RejectionReason,
    byte[] RowVersion,
    DateTime CreatedAt);

public sealed record RequestCaseClosureRequest(
    int CaseId,
    string ClosureReason,
    bool SymptomRemission,
    string? ClosureSummary);

public sealed record ApproveCaseClosureRequest(
    bool Approve,
    string? RejectionReason,
    byte[] RowVersion);

public sealed record ApproveCaseClosureResponse(
    CaseClosureDto Closure,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);
