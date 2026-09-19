namespace AKA.CMS.Domain.Entities;

public sealed class CaseAttachment
{
    public int AttachmentId { get; set; }
    public int CaseId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public string StoragePath { get; set; } = string.Empty;
    public int? UploadedBy { get; set; }
    public DateTime UploadedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
