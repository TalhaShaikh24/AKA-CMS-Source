namespace AKA.CMS.Application.DTOs;

public sealed record AttachmentDto(
    int AttachmentId,
    int CaseId,
    string FileName,
    string ContentType,
    long FileSizeBytes,
    int? UploadedBy,
    DateTime UploadedAt,
    DateTime CreatedAt);

public sealed record AttachmentUploadResponse(
    int AttachmentId,
    string FileName,
    string ContentType,
    long FileSizeBytes,
    DateTime UploadedAt);
