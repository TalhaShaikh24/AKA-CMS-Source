namespace AKA.CMS.Domain.Entities;

public sealed class CaseComment
{
    public int CaseCommentId { get; set; }
    public int CaseId { get; set; }
    public string CommentType { get; set; } = string.Empty;
    public string Comment { get; set; } = string.Empty;
    public int CreatedBy { get; set; }
    public string? CreatedByUsername { get; set; }
    public DateTime CreatedAt { get; set; }
}
