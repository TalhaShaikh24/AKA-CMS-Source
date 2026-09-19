namespace AKA.CMS.Application.DTOs;

public sealed record RecordCaseSourceRequest(
    string SourceType,
    int? SourceReferenceId);
