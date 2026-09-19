using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;

namespace AKA.CMS.Application.Services;

public sealed class FollowUpDueService(
    IFollowUpRepository followUpRepository) : IFollowUpDueService
{
    public async Task<IReadOnlyList<DueFollowUpDto>> GetDueAsync()
    {
        var due = await followUpRepository.GetDueAsync();
        return due.Select(d => d.ToDto()).ToList();
    }
}
