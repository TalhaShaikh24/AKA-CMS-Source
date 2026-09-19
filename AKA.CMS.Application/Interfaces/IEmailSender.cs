namespace AKA.CMS.Application.Interfaces;

/// <summary>Abstraction over e-mail delivery. Implemented with SMTP in Infrastructure.</summary>
public interface IEmailSender
{
    Task SendAsync(string to, string subject, string htmlBody, CancellationToken cancellationToken = default);
}
