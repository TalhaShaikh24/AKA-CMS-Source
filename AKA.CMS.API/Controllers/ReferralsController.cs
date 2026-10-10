using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Creates referrals and tracks accept/reject.</summary>
[ApiController]
[Route("api/referrals")]
[Authorize]
public sealed class ReferralsController(IReferralService referralService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(ReferralDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.ReferralsWrite)]
    public async Task<ActionResult<ReferralDto>> Create([FromBody] CreateReferralRequest request)
    {
        var referral = await referralService.CreateAsync(
            request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId = referral.CaseId },
            referral);
    }

    /// <summary>Update status.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(UpdateReferralStatusResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPatch("{referralId:int}/status")]
    [Authorize(Policy = PermissionPolicies.ReferralsWrite)]
    public async Task<ActionResult<UpdateReferralStatusResponse>> UpdateStatus(
        int referralId, [FromBody] UpdateReferralStatusRequest request)
        => Ok(await referralService.UpdateStatusAsync(
            referralId, request, currentUser.HasPermission,
            currentUser.UserId, ClientIpAddress));

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<ReferralDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case/{caseId:int}")]
    [Authorize(Policy = PermissionPolicies.ReferralsRead)]
    public async Task<ActionResult<IReadOnlyList<ReferralDto>>> GetByCase(int caseId)
        => Ok(await referralService.GetByCaseAsync(caseId));

    /// <summary>List recent referrals across cases (queue).</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<ReferralDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.ReferralsRead)]
    public async Task<ActionResult<IReadOnlyList<ReferralDto>>> GetAll([FromQuery] int top = 100)
        => Ok(await referralService.GetAllAsync(top));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
