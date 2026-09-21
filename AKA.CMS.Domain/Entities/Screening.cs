namespace AKA.CMS.Domain.Entities;

public sealed class Screening
{
    public int ScreeningId { get; set; }
    public int CaseId { get; set; }
    public int CommunityMemberId { get; set; }
    public string ToolCode { get; set; } = string.Empty;
    public string? ToolName { get; set; }
    public string ItemScores { get; set; } = string.Empty;
    public int RawScore { get; set; }
    public string RiskLevel { get; set; } = string.Empty;
    public string? RiskLevelName { get; set; }
    public string? SubscaleScoresJson { get; set; }
    public bool MentalHealthSynced { get; set; }
    public string? MentalHealthCode { get; set; }
    public int ScreenedBy { get; set; }
    public string? ScreenedByUsername { get; set; }
    public DateTime ScreenedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
