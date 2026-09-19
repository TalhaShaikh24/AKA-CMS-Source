namespace AKA.CMS.Application.Interfaces;

public sealed class ConcurrencyException(string message) : Exception(message);
