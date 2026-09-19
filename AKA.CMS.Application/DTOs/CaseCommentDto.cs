namespace AKA.CMS.Application.DTOs;

public sealed record CaseCommentDto(
    int CaseCommentId,
    int CaseId,
    string CommentType,
    string Comment,
    int CreatedBy,
    string? CreatedByUsername,
    DateTime CreatedAt);
