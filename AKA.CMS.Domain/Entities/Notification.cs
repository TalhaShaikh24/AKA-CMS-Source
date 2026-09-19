namespace AKA.CMS.Domain.Entities;

public sealed class Notification
{
    public int NotificationId { get; set; }
    public string? RecipientRole { get; set; }
    public int? RecipientUserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public int? RelatedCaseId { get; set; }
    public string? RelatedEntity { get; set; }
    public int? RelatedEntityId { get; set; }
    public bool IsRead { get; set; }
    public DateTime? ReadAt { get; set; }
    public string Status { get; set; } = "Unread";
    public string? PushPayload { get; set; }
    public DateTime CreatedAt { get; set; }
}
