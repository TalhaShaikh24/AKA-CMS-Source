using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.API.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Structured risk assessment per case (Case Log Revised).</summary>
[ApiController]
[Route("api/cases/{caseId:int}/risk-assessment")]
public sealed class RiskAssessmentsController : ControllerBase
{
    private readonly IRiskAssessmentService _service;
    private readonly ICurrentUser _currentUser;

    public RiskAssessmentsController(IRiskAssessmentService service, ICurrentUser currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    [HttpGet]
    [Authorize(Policy = PermissionPolicies.CasesRead)]
    public async Task<ActionResult<RiskAssessmentDto>> Get(int caseId)
    {
        var dto = await _service.GetByCaseAsync(caseId);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpPut]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<ActionResult<RiskAssessmentDto>> Save(int caseId, [FromBody] SaveRiskAssessmentRequest request)
        => Ok(await _service.SaveAsync(caseId, request, _currentUser.UserId));
}
