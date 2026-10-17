namespace AKA.CMS.Domain.Entities;

public sealed class CommunityMember
{
    public int MemberId { get; set; }
    public string? MrNo { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? FatherName { get; set; }
    public string? Gender { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? Cnic { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? UnionCouncilCode { get; set; }
    public string? VillageCode { get; set; }
    public int? Age { get; set; }
    public string? RegionCouncil { get; set; }
    public string? LocalCouncil { get; set; }
    public string? Village { get; set; }
    public string? JkAttend { get; set; }
    public string? EmploymentEducation { get; set; }
    public string? MaritalStatus { get; set; }
    public int? NumberOfChildren { get; set; }
    public string? LanguagesSpoken { get; set; }
    public string? HealthInsurance { get; set; }
    public string? GpUsualCare { get; set; }
    public string? PriorMhTreatment { get; set; }
    public string? ConnectedToMhCare { get; set; }
    public string? CareProviderName { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public DateTime? DateOfCall { get; set; }
    public string? EntryPoint { get; set; }
    public string? ReturningCaller { get; set; }
    public string? ConsentToProceed { get; set; }
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
