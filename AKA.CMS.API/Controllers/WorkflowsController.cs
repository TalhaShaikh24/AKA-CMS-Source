using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Form-section Workflow: which sections of a Dynamic Form
/// show or hide when the form loads. This is not the case workflow
/// engine (13 states / 22 transitions) — that lives under
/// WorkflowConfig. A workflow belongs to one form; only one workflow
/// per form is active at a time.</summary>
[ApiController]
[Route("api/workflows")]
[Authorize]
public sealed class WorkflowsController(IWorkflowService service, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowListItemDto>))]
    public async Task<ActionResult<IReadOnlyList<WorkflowListItemDto>>> GetAll()
        => Ok(await service.GetAllAsync());

    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowDetailDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowDetailDto>> GetById(int id)
        => Ok(await service.GetByIdAsync(id));

    /// <summary>Get Workflow Sections: the form's active workflow's
    /// sections in display order, each with its actions. Empty
    /// sections means no active workflow, and the form shows
    /// everything. This is the API the boss named — the Render page
    /// calls it on load and hides the sections it says to hide.</summary>
    [HttpGet("by-form/{formId:int}/sections")]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowSectionsResponseDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowSectionsResponseDto>> GetSectionsByForm(int formId)
        => Ok(await service.GetSectionsByFormAsync(formId));

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.WorkflowsWrite)]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(WorkflowDetailDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowDetailDto>> Create([FromBody] SaveWorkflowRequest request)
    {
        var created = await service.CreateAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { id = created.WorkflowId }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowsWrite)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowDetailDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowDetailDto>> Update(int id, [FromBody] SaveWorkflowRequest request)
        => Ok(await service.UpdateAsync(id, request, currentUser.UserId));

    [HttpDelete("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowsWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> Delete(int id)
    {
        await service.DeleteAsync(id, currentUser.UserId);
        return NoContent();
    }
}
