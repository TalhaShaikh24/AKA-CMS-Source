using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

/// <summary>
/// Crisis detection engine for the S7a-S7i emergency path.
/// Indicator -> crisis-type mapping is taken from the authoritative
/// client document (AKU Technical Proposal v1, Phase C "Crisis
/// Detection" trigger conditions):
///   suicidal intent -> SUI, severe self-harm risk -> SHM,
///   psychosis -> PSY, panic attack -> PAN, substance crisis -> SUB.
/// </summary>
public sealed class CrisisDetectionService : ICrisisDetectionService
{
    private static readonly (Func<CrisisIndicatorsDto, bool> Flag, string Code, bool Critical)[] Rules =
    [
        (i => i.SuicidalIntent,  "SUI", true),
        (i => i.SelfHarmRisk,    "SHM", true),
        (i => i.Psychosis,       "PSY", true),
        (i => i.PanicAttack,      "PAN", false),
        (i => i.SubstanceCrisis,  "SUB", false),
        (i => i.OtherAcute,       "OTH", false),
    ];

    public (string TypeCodesCsv, string? Severity, string IndicatorsJson) Detect(CrisisIndicatorsDto indicators)
    {
        ArgumentNullException.ThrowIfNull(indicators);

        var matched = Rules.Where(r => r.Flag(indicators)).ToList();
        var indicatorsJson = JsonSerializer.Serialize(indicators);

        if (matched.Count == 0)
            return (string.Empty, null, indicatorsJson);

        var severity = matched.Any(r => r.Critical) ? "CRITICAL" : "HIGH";
        return (string.Join(',', matched.Select(r => r.Code)), severity, indicatorsJson);
    }
}
