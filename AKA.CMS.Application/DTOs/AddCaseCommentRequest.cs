namespace AKA.CMS.Application.DTOs;

public sealed record AddCaseCommentRequest(
    int CaseId,
    string? CommentType,
    string Comment);
