using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Dynamic Form Builder — form definitions and their fields.</summary>
[ApiController]
[Route("api/dynamic-forms")]
[Authorize]
public sealed class DynamicFormsController(IDynamicFormService service, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.DynamicFormsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<DynamicFormListItemDto>))]
    public async Task<ActionResult<IReadOnlyList<DynamicFormListItemDto>>> GetAll()
        => Ok(await service.GetAllAsync());

    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(DynamicFormDetailDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<DynamicFormDetailDto>> GetById(int id)
        => Ok(await service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.DynamicFormsWrite)]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(DynamicFormDetailDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<DynamicFormDetailDto>> Create([FromBody] SaveDynamicFormRequest request)
    {
        var created = await service.CreateAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { id = created.FormId }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsWrite)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(DynamicFormDetailDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<DynamicFormDetailDto>> Update(int id, [FromBody] SaveDynamicFormRequest request)
        => Ok(await service.UpdateAsync(id, request, currentUser.UserId));

    [HttpDelete("{id:int}")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> Delete(int id)
    {
        await service.DeleteAsync(id, currentUser.UserId);
        return NoContent();
    }
}
