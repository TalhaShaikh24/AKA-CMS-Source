namespace AKA.CMS.Application.DTOs;

public sealed record SubmitScreeningRequest(
    int CaseId,
    string ToolCode,
    IReadOnlyList<int> ItemScores);
