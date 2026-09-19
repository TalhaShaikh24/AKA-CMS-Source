namespace AKA.CMS.Application.DTOs;

public sealed record UpdateReferralStatusRequest(
    string NewStatus,
    string? RejectionReason,
    byte[] RowVersion);
