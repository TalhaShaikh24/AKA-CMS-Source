using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Workflow steps and their per-step sections and buttons
/// (DZ_ChildCareV3 tbl_WorkFlowSteps / StepSectionPermission /
/// Step_Actions). Steps live under their workflow; sections and
/// buttons live under their step.</summary>
[ApiController]
[Route("api/workflows")]
[Authorize]
public sealed class WorkflowStepsController(IWorkflowStepService service, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet("{workflowId:int}/steps")]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowStepDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<WorkflowStepDto>>> GetByWorkflow(int workflowId)
        => Ok(await service.GetByWorkflowAsync(workflowId));

    [HttpPost("{workflowId:int}/steps")]
    [Authorize(Policy = PermissionPolicies.WorkflowStepsWrite)]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(WorkflowStepDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowStepDto>> Create(int workflowId, [FromBody] SaveWorkflowStepRequest request)
    {
        var created = await service.CreateAsync(workflowId, request, currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { stepId = created.WorkflowStepId }, created);
    }

    [HttpGet("steps/{stepId:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowStepDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowStepDto>> GetById(int stepId)
        => Ok(await service.GetByIdAsync(stepId));

    [HttpPut("steps/{stepId:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowStepsWrite)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowStepDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowStepDto>> Update(int stepId, [FromBody] SaveWorkflowStepRequest request)
        => Ok(await service.UpdateAsync(stepId, request, currentUser.UserId));

    [HttpDelete("steps/{stepId:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowStepsWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> Delete(int stepId)
    {
        await service.DeleteAsync(stepId, currentUser.UserId);
        return NoContent();
    }

    [HttpGet("steps/{stepId:int}/sections")]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowStepSectionDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<WorkflowStepSectionDto>>> GetSections(int stepId)
        => Ok(await service.GetSectionsByStepAsync(stepId));

    [HttpPut("steps/{stepId:int}/sections")]
    [Authorize(Policy = PermissionPolicies.WorkflowStepsWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> SaveSections(int stepId, [FromBody] List<SaveWorkflowStepSectionRequest> sections)
    {
        await service.SaveSectionsAsync(stepId, sections, currentUser.UserId);
        return NoContent();
    }

    [HttpGet("steps/{stepId:int}/actions")]
    [Authorize(Policy = PermissionPolicies.WorkflowsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowStepActionDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<WorkflowStepActionDto>>> GetActions(int stepId)
        => Ok(await service.GetActionsByStepAsync(stepId));

    [HttpPut("steps/{stepId:int}/actions")]
    [Authorize(Policy = PermissionPolicies.WorkflowStepsWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> SaveActions(int stepId, [FromBody] List<SaveWorkflowStepActionRequest> actions)
    {
        await service.SaveActionsAsync(stepId, actions, currentUser.UserId);
        return NoContent();
    }
}
