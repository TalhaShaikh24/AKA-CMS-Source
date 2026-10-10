namespace AKA.CMS.Application.DTOs;

public sealed record ReferralDto(
    int ReferralId,
    string ReferralNumber,
    int CaseId,
    string? CaseNumber,
    string ReferredTo,
    string Status,
    string? RejectionReason,
    int? ParentReferralId,
    string? ParentReferralNumber,
    DateTime SlaDueAt,
    string? Notes,
    int CreatedBy,
    string? CreatedByUsername,
    DateTime CreatedAt,
    byte[] RowVersion);
