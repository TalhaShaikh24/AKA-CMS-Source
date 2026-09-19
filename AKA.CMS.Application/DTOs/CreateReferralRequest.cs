namespace AKA.CMS.Application.DTOs;

public sealed record CreateReferralRequest(
    int CaseId,
    string ReferredTo,
    DateTime? SlaDueAt,
    string? Notes);
