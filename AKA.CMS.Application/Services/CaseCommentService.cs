using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CaseCommentService(
    ICaseCommentRepository commentRepository,
    IValidator<AddCaseCommentRequest> addValidator) : ICaseCommentService
{
    public async Task<CaseCommentDto> AddAsync(
        AddCaseCommentRequest request, int performedBy, string ipAddress)
    {
        await addValidator.ValidateAndThrowAsync(request);

        var commentId = await commentRepository.AddAsync(
            request.CaseId, request.CommentType, request.Comment,
            performedBy, ipAddress);

        var comments = await commentRepository.GetByCaseAsync(request.CaseId);
        return comments.First(c => c.CaseCommentId == commentId).ToDto();
    }

    public async Task<IReadOnlyList<CaseCommentDto>> GetByCaseAsync(int caseId)
    {
        var comments = await commentRepository.GetByCaseAsync(caseId);
        return comments.Select(c => c.ToDto()).ToList();
    }
}
