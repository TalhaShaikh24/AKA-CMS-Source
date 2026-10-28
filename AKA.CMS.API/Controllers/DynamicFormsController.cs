using System.Text.Json;
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

    /// <summary>Lookup options: the configured options of a field in another
    /// form (SharePoint-style lookup source). Empty when the source field
    /// has no configured options.</summary>
    [HttpGet("lookup-options")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<DynamicFormFieldOptionDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<DynamicFormFieldOptionDto>>> LookupOptions(
        [FromQuery] int formId, [FromQuery] string fieldKey)
        => Ok(await service.GetLookupOptionsAsync(formId, fieldKey));

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

    /* ---------------- submission entries ---------------- */

    /// <summary>Submit a filled-in form. Multipart form data: a "values"
    /// field with the JSON object of answers, plus one file part per file
    /// field named "file_{fieldKey}". Values are validated server-side
    /// (required, email, regex, length, range, file type) and failures
    /// come back as per-field errors.</summary>
    [HttpPost("{id:int}/submissions")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsSubmit)]
    [RequestSizeLimit(100_000_000)]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(DynamicFormSubmissionDetailDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<DynamicFormSubmissionDetailDto>> Submit(int id)
    {
        var form = Request.Form;
        var values = new Dictionary<string, JsonElement>(StringComparer.OrdinalIgnoreCase);
        var valuesRaw = form["values"].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(valuesRaw))
        {
            try
            {
                using var doc = JsonDocument.Parse(valuesRaw);
                if (doc.RootElement.ValueKind != JsonValueKind.Object)
                    return BadRequest("values must be a JSON object.");
                foreach (var prop in doc.RootElement.EnumerateObject())
                    values[prop.Name] = prop.Value.Clone();
            }
            catch (JsonException)
            {
                return BadRequest("values must be valid JSON.");
            }
        }

        var files = new List<SubmissionFileUpload>();
        foreach (var file in form.Files)
        {
            // Empty parts come from untouched file inputs; only real
            // uploads count.
            if (file.Length == 0 || !file.Name.StartsWith("file_", StringComparison.OrdinalIgnoreCase))
                continue;
            files.Add(new SubmissionFileUpload
            {
                FieldKey = file.Name["file_".Length..],
                FileName = file.FileName,
                ContentType = file.ContentType,
                Content = file.OpenReadStream()
            });
        }

        var created = await service.SubmitAsync(id, values, files, currentUser.UserId);
        return CreatedAtAction(nameof(GetSubmission), new { submissionId = created.SubmissionId }, created);
    }

    /// <summary>Entries list of one form, newest first.</summary>
    [HttpGet("{id:int}/submissions")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<DynamicFormSubmissionListItemDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<DynamicFormSubmissionListItemDto>>> GetSubmissions(int id)
        => Ok(await service.GetSubmissionsAsync(id));

    /// <summary>One entry in full, with every answered field's value.</summary>
    [HttpGet("submissions/{submissionId:int}")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(DynamicFormSubmissionDetailDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<DynamicFormSubmissionDetailDto>> GetSubmission(int submissionId)
        => Ok(await service.GetSubmissionAsync(submissionId));

    /// <summary>Delete one entry (and its uploaded files).</summary>
    [HttpDelete("submissions/{submissionId:int}")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> DeleteSubmission(int submissionId)
    {
        await service.DeleteSubmissionAsync(submissionId, currentUser.UserId);
        return NoContent();
    }

    /// <summary>Download a file attached to an entry.</summary>
    [HttpGet("submissions/{submissionId:int}/files/{fieldKey}")]
    [Authorize(Policy = PermissionPolicies.DynamicFormsRead)]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult> DownloadSubmissionFile(int submissionId, string fieldKey)
    {
        var (fileName, contentType, storagePath) = await service.GetSubmissionFileAsync(submissionId, fieldKey);
        return PhysicalFile(storagePath, contentType, fileName);
    }
}
