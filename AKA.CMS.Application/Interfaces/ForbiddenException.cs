
namespace AKA.CMS.Application.Interfaces;

public sealed class ForbiddenException(string message) : Exception(message);
