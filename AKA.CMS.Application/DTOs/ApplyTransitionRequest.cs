namespace AKA.CMS.Application.DTOs;

public sealed record ApplyTransitionRequest(
    string Action,
    string? Comment,
    int? AssignedToUserId,
    byte[] RowVersion);
