namespace AKA.CMS.Application.Interfaces;

public sealed class InvalidDomainValueException(string message) : Exception(message);
