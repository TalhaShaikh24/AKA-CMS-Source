using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseSourceRepository
{
    /// <summary>Records a case's identification source; throws ConflictException if one already exists.</summary>
    Task<(int MappingId, bool WasNew)> RecordAsync(
        int caseId, string sourceType, int? sourceReferenceId, int createdBy, string ipAddress);
    Task<CaseSourceMapping?> GetByCaseAsync(int caseId);
    Task<IReadOnlyList<CaseSourceType>> GetTypesAsync();
}
