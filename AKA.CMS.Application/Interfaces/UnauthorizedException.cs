
namespace AKA.CMS.Application.Interfaces;

public sealed class UnauthorizedException(string message) : Exception(message);
