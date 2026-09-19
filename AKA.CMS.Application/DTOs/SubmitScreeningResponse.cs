namespace AKA.CMS.Application.DTOs;

public sealed record SubmitScreeningResponse(
    ScreeningDto Screening,
    bool AutoTransitionApplied,
    string? AutoTransitionNote);
