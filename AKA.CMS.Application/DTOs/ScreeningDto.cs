namespace AKA.CMS.Application.DTOs;

public sealed record ScreeningDto(
    int ScreeningId,
    int CaseId,
    int CommunityMemberId,
    string ToolCode,
    string? ToolName,
    IReadOnlyList<int> ItemScores,
    int RawScore,
    string RiskLevel,
    string? RiskLevelName,
    string? SubscaleScoresJson,
    bool MentalHealthSynced,
    string? MentalHealthCode,
    int ScreenedBy,
    string? ScreenedByUsername,
    DateTime ScreenedAt,
    byte[] RowVersion);
