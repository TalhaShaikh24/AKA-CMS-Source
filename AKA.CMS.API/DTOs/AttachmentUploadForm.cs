using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.DTOs;

/// <summary>
/// Multipart form for case-attachment upload. Encapsulating the fields in a
/// DTO (instead of separate [FromForm] action parameters) is also what lets
/// Swashbuckle generate the Swagger schema for this endpoint.
/// </summary>
public sealed class AttachmentUploadForm
{
    [FromForm(Name = "caseId")]
    public int CaseId { get; set; }

    [FromForm(Name = "file")]
    public IFormFile? File { get; set; }
}
