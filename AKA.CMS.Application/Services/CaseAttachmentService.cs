using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using Microsoft.Extensions.Options;

namespace AKA.CMS.Application.Services;

public sealed class CaseAttachmentService(
    ICaseAttachmentRepository attachmentRepository,
    IOptions<FileStorageOptions> storageOptions) : ICaseAttachmentService
{
    private const string MaxBytesKey = "Attachments.MaxAttachmentBytes";
    private const string AllowedTypesKey = "Attachments.AllowedAttachmentTypes";

    public async Task<AttachmentUploadResponse> UploadAsync(
        int caseId, string fileName, string contentType, long fileSizeBytes,
        Stream content, int uploadedBy)
    {
        var safeName = SanitizeFileName(fileName);
        await ValidateAgainstSettingsAsync(safeName, fileSizeBytes);

        var directory = Path.Combine(ResolveUploadsPath(), caseId.ToString());
        Directory.CreateDirectory(directory);
        var storedName = $"{Guid.NewGuid():N}_{safeName}";
        var fullPath = Path.Combine(directory, storedName);

        try
        {
            await using var fileStream = new FileStream(fullPath, FileMode.CreateNew, FileAccess.Write);
            await content.CopyToAsync(fileStream);

            var attachmentId = await attachmentRepository.UploadMetadataAsync(
                caseId, safeName, contentType, fileSizeBytes, fullPath, uploadedBy);

            var attachment = await attachmentRepository.GetByIdAsync(attachmentId);
            return new AttachmentUploadResponse(
                attachment.AttachmentId, attachment.FileName,
                attachment.ContentType, attachment.FileSizeBytes, attachment.UploadedAt);
        }
        catch
        {
            if (File.Exists(fullPath))
                File.Delete(fullPath);
            throw;
        }
    }

    public async Task<IReadOnlyList<AttachmentDto>> GetByCaseAsync(int caseId)
    {
        var attachments = await attachmentRepository.GetByCaseAsync(caseId);
        return attachments.Select(a => a.ToDto()).ToList();
    }

    public async Task<(AttachmentDto Attachment, string StoragePath)> GetDownloadAsync(int attachmentId)
    {
        var attachment = await attachmentRepository.GetByIdAsync(attachmentId);
        if (!File.Exists(attachment.StoragePath))
            throw new NotFoundException($"Attachment file for id {attachmentId} is missing on disk.");
        return (attachment.ToDto(), attachment.StoragePath);
    }

    private async Task ValidateAgainstSettingsAsync(string fileName, long fileSizeBytes)
    {
        var maxBytesRaw = await attachmentRepository.GetSettingAsync(MaxBytesKey);
        if (long.TryParse(maxBytesRaw, out var maxBytes) && fileSizeBytes > maxBytes)
            throw new ScreeningValidationException("Attachment exceeds the maximum allowed size.");

        var allowedRaw = await attachmentRepository.GetSettingAsync(AllowedTypesKey);
        if (!string.IsNullOrWhiteSpace(allowedRaw))
        {
            var allowed = allowedRaw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var extension = Path.GetExtension(fileName).TrimStart('.').ToLowerInvariant();
            if (!allowed.Contains(extension, StringComparer.OrdinalIgnoreCase))
                throw new ScreeningValidationException("Attachment type is not allowed.");
        }
    }

    private string ResolveUploadsPath()
    {
        var path = storageOptions.Value.UploadsPath;
        if (string.IsNullOrWhiteSpace(path))
            throw new ScreeningValidationException("File storage is not configured.");
        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(path));
    }

    private static string SanitizeFileName(string fileName)
    {
        var name = Path.GetFileName(fileName ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(name))
            throw new ScreeningValidationException("A file name is required.");
        var invalid = Path.GetInvalidFileNameChars();
        name = new string(name.Where(c => !invalid.Contains(c)).ToArray()).Trim();
        if (string.IsNullOrWhiteSpace(name) || name.Length > 200)
            throw new ScreeningValidationException("The file name is not valid.");
        return name;
    }
}
