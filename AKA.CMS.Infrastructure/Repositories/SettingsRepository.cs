using System.Data;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class SettingsRepository(DapperContext context) : ISettingsRepository
{
    private sealed class UserSettingsRow
    {
        public int UserId { get; set; }
        public string? Username { get; set; }
        public string? Email { get; set; }
        public string? DisplayName { get; set; }
        public string? Phone { get; set; }
        public string? Region { get; set; }
        public string? Bio { get; set; }
        public bool EmailAlerts { get; set; }
        public bool SmsReminders { get; set; }
        public bool FollowUpDigests { get; set; }
        public bool CrisisAlerts { get; set; }
    }

    private async Task<UserSettingsRow?> GetRowAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@UserId", userId);
        return await connection.QuerySingleOrDefaultAsync<UserSettingsRow>(
            StoredProcedures.UserSettingsGet, p, commandType: CommandType.StoredProcedure);
    }

    public async Task<UserProfileDto?> GetProfileAsync(int userId)
    {
        var row = await GetRowAsync(userId);
        return row is null ? null : new UserProfileDto
        {
            UserId = row.UserId,
            Username = row.Username,
            Email = row.Email,
            DisplayName = row.DisplayName,
            Phone = row.Phone,
            Region = row.Region,
            Bio = row.Bio
        };
    }

    public async Task SaveProfileAsync(int userId, UpdateProfileRequest request)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@UserId", userId);
        p.Add("@DisplayName", request.DisplayName);
        p.Add("@Phone", request.Phone);
        p.Add("@Region", request.Region);
        p.Add("@Bio", request.Bio);
        p.Add("@Email", request.Email);
        await connection.ExecuteAsync(
            StoredProcedures.UserSettingsSaveProfile, p, commandType: CommandType.StoredProcedure);
    }

    public async Task<NotificationPrefsDto> GetNotificationsAsync(int userId)
    {
        var row = await GetRowAsync(userId);
        return new NotificationPrefsDto
        {
            EmailAlerts = row?.EmailAlerts ?? true,
            SmsReminders = row?.SmsReminders ?? true,
            FollowUpDigests = row?.FollowUpDigests ?? false,
            CrisisAlerts = row?.CrisisAlerts ?? true
        };
    }

    public async Task SaveNotificationsAsync(int userId, UpdateNotificationPrefsRequest request)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@UserId", userId);
        p.Add("@EmailAlerts", request.EmailAlerts);
        p.Add("@SmsReminders", request.SmsReminders);
        p.Add("@FollowUpDigests", request.FollowUpDigests);
        p.Add("@CrisisAlerts", request.CrisisAlerts);
        await connection.ExecuteAsync(
            StoredProcedures.UserSettingsSaveNotifications, p, commandType: CommandType.StoredProcedure);
    }

    public async Task<SystemSettingsDto> GetSystemAsync()
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<(string SettingKey, string? SettingValue)>(
            StoredProcedures.SystemSettingsGet, commandType: CommandType.StoredProcedure);
        var dict = rows.ToDictionary(r => r.SettingKey, r => r.SettingValue);
        return new SystemSettingsDto
        {
            DefaultRegion = dict.GetValueOrDefault("DefaultRegion"),
            SessionTimeout = int.TryParse(dict.GetValueOrDefault("SessionTimeout"), out var t) ? t : 30,
            DataRetentionMonths = int.TryParse(dict.GetValueOrDefault("DataRetentionMonths"), out var r) ? r : 24
        };
    }

    public async Task SaveSystemAsync(UpdateSystemSettingsRequest request, int updatedBy)
    {
        using var connection = context.CreateConnection();
        foreach (var (key, value) in new[]
                 {
                     ("DefaultRegion", request.DefaultRegion),
                     ("SessionTimeout", request.SessionTimeout.ToString()),
                     ("DataRetentionMonths", request.DataRetentionMonths.ToString())
                 })
        {
            var p = new DynamicParameters();
            p.Add("@SettingKey", key);
            p.Add("@SettingValue", value);
            p.Add("@UpdatedBy", updatedBy);
            await connection.ExecuteAsync(
                StoredProcedures.SystemSettingsSave, p, commandType: CommandType.StoredProcedure);
        }
    }
}
