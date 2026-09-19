using System.Net;
using System.Net.Mail;
using AKA.CMS.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace AKA.CMS.Infrastructure.Email;

/// <summary>SMTP e-mail delivery over <see cref="SmtpClient"/>. No third-party
/// packages required. A new client is created per message; nothing is shared.</summary>
public sealed class SmtpEmailSender(SmtpOptions options, ILogger<SmtpEmailSender> logger) : IEmailSender
{
    public async Task SendAsync(string to, string subject, string htmlBody, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(to);

        if (!options.IsConfigured)
            throw new InvalidOperationException(
                "SMTP is not configured. Set the Smtp section (Host, FromAddress, credentials) in configuration.");

        using var message = new MailMessage
        {
            From = new MailAddress(options.FromAddress, options.FromName),
            Subject = subject,
            Body = htmlBody,
            IsBodyHtml = true
        };
        message.To.Add(to.Trim());

        using var client = new SmtpClient(options.Host, options.Port)
        {
            EnableSsl = options.EnableSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Timeout = 30_000
        };
        if (!string.IsNullOrWhiteSpace(options.Username))
            client.Credentials = new NetworkCredential(options.Username, options.Password);

        logger.LogInformation("Sending e-mail to {To} via {Host}:{Port}", to, options.Host, options.Port);
        await client.SendMailAsync(message, cancellationToken);
    }
}
