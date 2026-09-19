
namespace AKA.CMS.Application.Interfaces;

public sealed class NotFoundException(string message) : Exception(message);
