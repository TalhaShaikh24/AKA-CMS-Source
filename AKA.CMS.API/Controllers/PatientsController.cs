using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Patient identity: search and MR resolution.</summary>
[ApiController]
[Route("api/patients")]
[Authorize]
public sealed class PatientsController(IPatientService patientService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Search.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<PatientSearchResultDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("search")]
    [Authorize(Policy = PermissionPolicies.PatientsRead)]
    public async Task<ActionResult<IReadOnlyList<PatientSearchResultDto>>> Search(
        [FromQuery] string? mr, [FromQuery] string? q)
        => Ok(await patientService.SearchAsync(mr ?? q));

    /// <summary>Get a community member by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CommunityMemberDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("members/{id:int}")]
    [Authorize(Policy = PermissionPolicies.PatientsRead)]
    public async Task<ActionResult<CommunityMemberDto>> GetMemberById(int id)
        => Ok(await patientService.GetCommunityMemberByIdAsync(id));

    /// <summary>Resolve identity.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(ResolveIdentityResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("resolve-identity")]
    [Authorize(Policy = PermissionPolicies.PatientsWrite)]
    public async Task<ActionResult<ResolveIdentityResponse>> ResolveIdentity(
        [FromBody] ResolveIdentityRequest request)
    {
        var result = await patientService.ResolveIdentityAsync(
            request, currentUser.UserId, ClientIpAddress);
        return result.WasCreated
            ? CreatedAtAction(nameof(Search), new { mr = result.MrNo }, result)
            : Ok(result);
    }

    /// <summary>Remap mr.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ResolveIdentityResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost("remap-mr")]
    [Authorize(Policy = PermissionPolicies.PatientsWrite)]
    public async Task<ActionResult<ResolveIdentityResponse>> RemapMr([FromBody] RemapMrRequest request)
        => Ok(await patientService.RemapMrAsync(request, currentUser.UserId, ClientIpAddress));

    /// <summary>Register member.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(CommunityMemberDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("members")]
    [Authorize(Policy = PermissionPolicies.PatientsWrite)]
    public async Task<ActionResult<CommunityMemberDto>> RegisterMember(
        [FromBody] CreateCommunityMemberRequest request)
    {
        var created = await patientService.RegisterCommunityMemberAsync(
            request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(Search), new { q = created.FullName }, created);
    }

    /// <summary>Get mr blocks.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<FacilityMrBlockDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("mr-blocks")]
    [Authorize(Policy = PermissionPolicies.PatientsRead)]
    public async Task<ActionResult<IReadOnlyList<FacilityMrBlockDto>>> GetMrBlocks()
        => Ok(await patientService.GetMrBlocksAsync());

    /// <summary>Upsert mr block.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPut("mr-blocks")]
    [Authorize(Policy = PermissionPolicies.PatientsWrite)]
    public async Task<IActionResult> UpsertMrBlock([FromBody] UpsertFacilityMrBlockRequest request)
    {
        await patientService.UpsertMrBlockAsync(request, currentUser.UserId);
        return NoContent();
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
