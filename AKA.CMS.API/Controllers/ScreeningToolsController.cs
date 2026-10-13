using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.API.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Dynamic screening tool + question management.</summary>
[ApiController]
[Route("api/screening-tools")]
public sealed class ScreeningToolsController : ControllerBase
{
    private readonly IScreeningToolService _service;
    private readonly ICurrentUser _currentUser;

    public ScreeningToolsController(IScreeningToolService service, ICurrentUser currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    /// <summary>Active tools with questions — for screening forms.</summary>
    [HttpGet("active")]
    [Authorize(Policy = PermissionPolicies.ScreeningsRead)]
    public async Task<ActionResult<IReadOnlyList<ScreeningToolDefDto>>> GetActive()
        => Ok(await _service.GetActiveAsync());

    /// <summary>All tools — admin management list.</summary>
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.ScreeningsWrite)]
    public async Task<ActionResult<IReadOnlyList<ScreeningToolDefDto>>> GetAll()
        => Ok(await _service.GetAllAsync());

    [HttpGet("{code}")]
    [Authorize(Policy = PermissionPolicies.ScreeningsWrite)]
    public async Task<ActionResult<ScreeningToolDefDto>> GetById(string code)
        => Ok(await _service.GetByIdAsync(code));

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.ScreeningsWrite)]
    public async Task<ActionResult> Create([FromBody] CreateScreeningToolRequest request)
    {
        await _service.CreateAsync(request, _currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { code = request.ToolCode }, null);
    }

    [HttpPut("{code}")]
    [Authorize(Policy = PermissionPolicies.ScreeningsWrite)]
    public async Task<ActionResult> Update(string code, [FromBody] UpdateScreeningToolRequest request)
    {
        await _service.UpdateAsync(code, request, _currentUser.UserId);
        return NoContent();
    }
}
