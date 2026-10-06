namespace AKA.CMS.Application.DTOs;

/// <summary>Self-service profile update: the signed-in user edits their own
/// e-mail and/or password. Admin-only fields (IsActive, IsLocked) are not
/// part of this contract.</summary>
public sealed record UpdateMyProfileRequest(
    string? Email,
    string? NewPassword);
