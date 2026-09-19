namespace AKA.CMS.Application.DTOs;

public sealed record FollowUpComplianceDto(IReadOnlyList<LabelCountDto> Statuses);
