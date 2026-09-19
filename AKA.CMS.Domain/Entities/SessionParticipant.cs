namespace AKA.CMS.Domain.Entities;

public sealed class SessionParticipant
{
    public int ParticipantId { get; set; }
    public int SessionId { get; set; }
    public int? CommunityMemberId { get; set; }
    public string? MemberName { get; set; }
    public string? ParticipantName { get; set; }
    public bool Attended { get; set; }
    public bool ConsentedToScreening { get; set; }
    public int? ScreeningId { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}
