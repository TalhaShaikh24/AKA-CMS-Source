namespace AKA.CMS.Application.DTOs;

public sealed record AssignCaseRequest(
    int UserId,
    byte[] RowVersion);
