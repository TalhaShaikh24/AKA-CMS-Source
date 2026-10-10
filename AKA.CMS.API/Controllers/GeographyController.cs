using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Geography master data (regions, local councils, villages).</summary>
[ApiController]
[Route("api/geography")]
[Authorize]
public sealed class GeographyController(
    IGeographyService geographyService, ICurrentUser currentUser) : ControllerBase
{
    /* ---------------- Regions ---------------- */

    /// <summary>List regions.</summary>
    [HttpGet("regions")]
    [Authorize(Policy = PermissionPolicies.GeographyRead)]
    public async Task<ActionResult<IReadOnlyList<RegionDto>>> GetRegions(
        [FromQuery] bool includeInactive = false)
        => Ok(await geographyService.GetRegionsAsync(includeInactive));

    /// <summary>Get a region by id.</summary>
    [HttpGet("regions/{id:int}")]
    [Authorize(Policy = PermissionPolicies.GeographyRead)]
    public async Task<ActionResult<RegionDto>> GetRegionById(int id)
        => Ok(await geographyService.GetRegionByIdAsync(id));

    /// <summary>Create a region.</summary>
    [HttpPost("regions")]
    [Authorize(Policy = PermissionPolicies.GeographyWrite)]
    public async Task<ActionResult<RegionDto>> CreateRegion([FromBody] CreateRegionRequest request)
    {
        var created = await geographyService.CreateRegionAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetRegionById), new { id = created.RegionId }, created);
    }

    /// <summary>Update a region.</summary>
    [HttpPut("regions/{id:int}")]
    [Authorize(Policy = PermissionPolicies.GeographyWrite)]
    public async Task<ActionResult<RegionDto>> UpdateRegion(int id, [FromBody] UpdateRegionRequest request)
        => Ok(await geographyService.UpdateRegionAsync(id, request, currentUser.UserId, ClientIpAddress));

    /* ---------------- Local councils ---------------- */

    /// <summary>List local councils (optionally filtered by region).</summary>
    [HttpGet("councils")]
    [Authorize(Policy = PermissionPolicies.GeographyRead)]
    public async Task<ActionResult<IReadOnlyList<LocalCouncilDto>>> GetLocalCouncils(
        [FromQuery] int? regionId = null,
        [FromQuery] bool includeInactive = false)
        => Ok(await geographyService.GetLocalCouncilsAsync(regionId, includeInactive));

    /// <summary>Get a local council by id.</summary>
    [HttpGet("councils/{id:int}")]
    [Authorize(Policy = PermissionPolicies.GeographyRead)]
    public async Task<ActionResult<LocalCouncilDto>> GetLocalCouncilById(int id)
        => Ok(await geographyService.GetLocalCouncilByIdAsync(id));

    /// <summary>Create a local council.</summary>
    [HttpPost("councils")]
    [Authorize(Policy = PermissionPolicies.GeographyWrite)]
    public async Task<ActionResult<LocalCouncilDto>> CreateLocalCouncil([FromBody] CreateLocalCouncilRequest request)
    {
        var created = await geographyService.CreateLocalCouncilAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetLocalCouncilById), new { id = created.CouncilId }, created);
    }

    /// <summary>Update a local council.</summary>
    [HttpPut("councils/{id:int}")]
    [Authorize(Policy = PermissionPolicies.GeographyWrite)]
    public async Task<ActionResult<LocalCouncilDto>> UpdateLocalCouncil(int id, [FromBody] UpdateLocalCouncilRequest request)
        => Ok(await geographyService.UpdateLocalCouncilAsync(id, request, currentUser.UserId, ClientIpAddress));

    /* ---------------- Villages ---------------- */

    /// <summary>List villages (optionally filtered by council).</summary>
    [HttpGet("villages")]
    [Authorize(Policy = PermissionPolicies.GeographyRead)]
    public async Task<ActionResult<IReadOnlyList<VillageDto>>> GetVillages(
        [FromQuery] int? councilId = null,
        [FromQuery] bool includeInactive = false)
        => Ok(await geographyService.GetVillagesAsync(councilId, includeInactive));

    /// <summary>Get a village by id.</summary>
    [HttpGet("villages/{id:int}")]
    [Authorize(Policy = PermissionPolicies.GeographyRead)]
    public async Task<ActionResult<VillageDto>> GetVillageById(int id)
        => Ok(await geographyService.GetVillageByIdAsync(id));

    /// <summary>Create a village.</summary>
    [HttpPost("villages")]
    [Authorize(Policy = PermissionPolicies.GeographyWrite)]
    public async Task<ActionResult<VillageDto>> CreateVillage([FromBody] CreateVillageRequest request)
    {
        var created = await geographyService.CreateVillageAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetVillageById), new { id = created.VillageId }, created);
    }

    /// <summary>Update a village.</summary>
    [HttpPut("villages/{id:int}")]
    [Authorize(Policy = PermissionPolicies.GeographyWrite)]
    public async Task<ActionResult<VillageDto>> UpdateVillage(int id, [FromBody] UpdateVillageRequest request)
        => Ok(await geographyService.UpdateVillageAsync(id, request, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
