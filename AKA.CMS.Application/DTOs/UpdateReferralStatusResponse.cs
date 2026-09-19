namespace AKA.CMS.Application.DTOs;

public sealed record UpdateReferralStatusResponse(
    int ReferralId,
    string Status,
    int? NewReferralId,
    string? Note);
