using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages prescriptions, dispensing and the formulary.</summary>
[ApiController]
[Route("api/medications")]
[Authorize]
public sealed class MedicationsController(
    IMedicationService medicationService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get dictionary.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<MedicationDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("dictionary")]
    [Authorize(Policy = PermissionPolicies.MedicationsRead)]
    public async Task<ActionResult<IReadOnlyList<MedicationDto>>> GetDictionary()
        => Ok(await medicationService.GetDictionaryAsync());

    /// <summary>Get prescriptions.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<MedicationPrescriptionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("prescriptions")]
    [Authorize(Policy = PermissionPolicies.MedicationsRead)]
    public async Task<ActionResult<IReadOnlyList<MedicationPrescriptionDto>>> GetPrescriptions(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        return Ok(await medicationService.GetPrescriptionsByCaseAsync(caseId.Value));
    }

    /// <summary>Create prescription.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(MedicationPrescriptionDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("prescriptions")]
    [Authorize(Policy = PermissionPolicies.MedicationsWrite)]
    public async Task<ActionResult<MedicationPrescriptionDto>> CreatePrescription(
        [FromBody] CreatePrescriptionRequest request)
    {
        var created = await medicationService.CreatePrescriptionAsync(
            request, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    /// <summary>Cancel prescription.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPatch("prescriptions/{id:int}/cancel")]
    [Authorize(Policy = PermissionPolicies.MedicationsWrite)]
    public async Task<IActionResult> CancelPrescription(
        int id, [FromBody] CancelPrescriptionRequest request)
    {
        await medicationService.CancelPrescriptionAsync(
            id, request.RowVersion, currentUser.UserId, ClientIpAddress);
        return NoContent();
    }

    /// <summary>Dispense.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(int))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("prescriptions/{id:int}/dispense")]
    [Authorize(Policy = PermissionPolicies.MedicationsWrite)]
    public async Task<ActionResult<int>> Dispense(int id, [FromBody] DispenseMedicationRequest request)
    {
        var dispenseId = await medicationService.DispenseAsync(
            id, request, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, dispenseId);
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
