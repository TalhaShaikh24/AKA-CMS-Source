namespace AKA.CMS.Application.DTOs;

public sealed class UserProfileDto
{
    public int UserId { get; set; }
    public string? Username { get; set; }
    public string? Email { get; set; }
    public string? DisplayName { get; set; }
    public string? Phone { get; set; }
    public string? Region { get; set; }
    public List<string> Regions { get; set; } = new();
    public string? Bio { get; set; }
}

public sealed class UpdateProfileRequest
{
    public string? DisplayName { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Region { get; set; }
    public List<string>? Regions { get; set; }
    public string? Bio { get; set; }
}

public sealed class NotificationPrefsDto
{
    public bool EmailAlerts { get; set; }
    public bool SmsReminders { get; set; }
    public bool FollowUpDigests { get; set; }
    public bool CrisisAlerts { get; set; }
}

public sealed class UpdateNotificationPrefsRequest
{
    public bool EmailAlerts { get; set; }
    public bool SmsReminders { get; set; }
    public bool FollowUpDigests { get; set; }
    public bool CrisisAlerts { get; set; }
}

public sealed class SystemSettingsDto
{
    public string? DefaultRegion { get; set; }
    public int SessionTimeout { get; set; }
    public int DataRetentionMonths { get; set; }
}

public sealed class UpdateSystemSettingsRequest
{
    public string? DefaultRegion { get; set; }
    public int SessionTimeout { get; set; }
    public int DataRetentionMonths { get; set; }
}
