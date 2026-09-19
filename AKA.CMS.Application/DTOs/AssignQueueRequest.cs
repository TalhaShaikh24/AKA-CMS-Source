namespace AKA.CMS.Application.DTOs;

public sealed record AssignQueueRequest(
    int AssignedToUserId,
    byte[] RowVersion);
