using System.Net;
using AKA.CMS.Application.Interfaces;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Middleware;

public sealed class ExceptionHandlingMiddleware(
    RequestDelegate next,
    ILogger<ExceptionHandlingMiddleware> logger,
    IWebHostEnvironment environment)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception processing {Path}", context.Request.Path);
            await WriteProblemAsync(context, ex);
        }
    }

    private Task WriteProblemAsync(HttpContext context, Exception ex)
    {
        var (status, title) = ex switch
        {
            ValidationException => (HttpStatusCode.BadRequest, "Validation failed."),
            ScreeningValidationException => (HttpStatusCode.BadRequest, "Validation failed."),
            InvalidDomainValueException => (HttpStatusCode.BadRequest, "Invalid value."),
            UnauthorizedException => (HttpStatusCode.Unauthorized, "Unauthorized."),
            ForbiddenException => (HttpStatusCode.Forbidden, "Forbidden."),
            NotFoundException => (HttpStatusCode.NotFound, "Not found."),
            ConflictException => (HttpStatusCode.Conflict, "Conflict."),
            ConcurrencyException => (HttpStatusCode.Conflict, "The record was modified by another user."),
            WorkflowException => (HttpStatusCode.BadRequest, "Workflow transition not allowed."),
            _ => (HttpStatusCode.InternalServerError, "An unexpected error occurred.")
        };

        // In Development, surface the real exception message so API consumers
        // can diagnose the problem; in Production the detail stays generic and
        // the correlationId ties the payload to the server logs.
        var detail = status == HttpStatusCode.InternalServerError
            ? (environment.IsDevelopment() ? ex.Message : title)
            : ex.Message;

        var problem = new ProblemDetails
        {
            Status = (int)status,
            Title = title,
            Detail = detail,
            Instance = context.Request.Path
        };

        // Correlate the error payload with the request's log lines.
        if (context.Items.TryGetValue(CorrelationIdMiddleware.HeaderName, out var correlationId)
            && correlationId is string cid)
        {
            problem.Extensions["correlationId"] = cid;
        }

        if (ex is ValidationException vex)
            problem.Extensions["errors"] = vex.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());

        context.Response.StatusCode = (int)status;
        context.Response.ContentType = "application/problem+json";
        return context.Response.WriteAsJsonAsync(problem);
    }
}
