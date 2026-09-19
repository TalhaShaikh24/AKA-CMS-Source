using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages notes/comments on cases.</summary>
[ApiController]
[Route("api/case-comments")]
[Authorize]
public sealed class CaseCommentsController(ICaseCommentService commentService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Add.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(CaseCommentDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.CaseCommentsWrite)]
    public async Task<ActionResult<CaseCommentDto>> Add([FromBody] AddCaseCommentRequest request)
    {
        var comment = await commentService.AddAsync(
            request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId = comment.CaseId },
            comment);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<CaseCommentDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case/{caseId:int}")]
    [Authorize(Policy = PermissionPolicies.CaseCommentsRead)]
    public async Task<ActionResult<IReadOnlyList<CaseCommentDto>>> GetByCase(int caseId)
        => Ok(await commentService.GetByCaseAsync(caseId));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
