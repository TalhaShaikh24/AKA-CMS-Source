namespace AKA.CMS.Application.DTOs;

public sealed record ScreeningRiskBandDto(
    string BandCode,
    string BandName,
    int MinScore,
    int MaxScore);
