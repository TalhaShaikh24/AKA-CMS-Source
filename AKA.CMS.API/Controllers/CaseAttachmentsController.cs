using AKA.CMS.API.Auth;
using AKA.CMS.API.DTOs;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Uploads and lists case file attachments.</summary>
[ApiController]
[Authorize]
public sealed class CaseAttachmentsController(
    ICaseAttachmentService attachmentService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Upload.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(AttachmentUploadResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("api/case-attachments")]
    [Authorize(Policy = PermissionPolicies.AttachmentsWrite)]
    [RequestSizeLimit(200_000_000)]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<AttachmentUploadResponse>> Upload(
        [FromForm] AttachmentUploadForm form)
    {
        var file = form.File;
        if (file is null || file.Length == 0)
            return BadRequest("A non-empty file is required.");
        if (form.CaseId <= 0)
            return BadRequest("caseId is required.");

        await using var stream = file.OpenReadStream();
        var result = await attachmentService.UploadAsync(
            form.CaseId, file.FileName, file.ContentType, file.Length,
            stream, currentUser.UserId);
        return CreatedAtAction(nameof(Download), new { id = result.AttachmentId }, result);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<AttachmentDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("api/cases/{caseId:int}/attachments")]
    [Authorize(Policy = PermissionPolicies.AttachmentsRead)]
    public async Task<ActionResult<IReadOnlyList<AttachmentDto>>> GetByCase(int caseId)
        => Ok(await attachmentService.GetByCaseAsync(caseId));

    /// <summary>Download.</summary>
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("api/case-attachments/{id:int}/download")]
    [Authorize(Policy = PermissionPolicies.AttachmentsRead)]
    public async Task<ActionResult> Download(int id)
    {
        var (attachment, storagePath) = await attachmentService.GetDownloadAsync(id);
        return PhysicalFile(storagePath, attachment.ContentType, attachment.FileName);
    }
}
