namespace AKA.CMS.Domain.Entities;

public sealed class PsychModalityType
{
    public string ModalityCode { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsClientSourced { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
}
