using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseAttachmentRepository
{
    Task<int> UploadMetadataAsync(
        int caseId, string fileName, string contentType,
        long fileSizeBytes, string storagePath, int uploadedBy);
    Task<IReadOnlyList<CaseAttachment>> GetByCaseAsync(int caseId);
    Task<CaseAttachment> GetByIdAsync(int attachmentId);
    Task<string?> GetSettingAsync(string settingKey);
}
