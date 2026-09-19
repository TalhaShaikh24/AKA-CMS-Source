using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseAttachmentService
{
    Task<AttachmentUploadResponse> UploadAsync(
        int caseId, string fileName, string contentType, long fileSizeBytes,
        Stream content, int uploadedBy);
    Task<IReadOnlyList<AttachmentDto>> GetByCaseAsync(int caseId);
    Task<(AttachmentDto Attachment, string StoragePath)> GetDownloadAsync(int attachmentId);
}
