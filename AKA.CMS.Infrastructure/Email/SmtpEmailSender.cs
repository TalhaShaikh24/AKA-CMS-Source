using AKA.CMS.Application.Interfaces;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace AKA.CMS.Infrastructure.Email;

/// <summary>SMTP e-mail delivery over MailKit. Supports both STARTTLS
/// (e.g. port 587) and implicit TLS (port 465) — the latter is not possible
/// with System.Net.Mail.SmtpClient. Port 465 always uses implicit TLS;
/// any other port follows <see cref="SmtpOptions.EnableSsl"/>.</summary>
public sealed class SmtpEmailSender(SmtpOptions options, ILogger<SmtpEmailSender> logger) : IEmailSender
{
    public async Task SendAsync(string to, string subject, string htmlBody, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(to);

        if (!options.IsConfigured)
            throw new InvalidOperationException(
                "SMTP is not configured. Set the Smtp section (Host, FromAddress, credentials) in configuration.");

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(options.FromName, options.FromAddress));
        message.To.Add(MailboxAddress.Parse(to.Trim()));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = htmlBody };

        using var client = new SmtpClient();
        try
        {
            logger.LogInformation(
                "Sending e-mail to {To} via {Host}:{Port} ({Security})",
                to, options.Host, options.Port, GetSecureSocketOptions(options.Port, options.EnableSsl));

            await client.ConnectAsync(
                options.Host, options.Port,
                GetSecureSocketOptions(options.Port, options.EnableSsl),
                cancellationToken);

            if (!string.IsNullOrWhiteSpace(options.Username))
                await client.AuthenticateAsync(options.Username, options.Password, cancellationToken);

            await client.SendAsync(message, cancellationToken);
        }
        finally
        {
            if (client.IsConnected)
                await client.DisconnectAsync(true, cancellationToken);
        }
    }

    internal static SecureSocketOptions GetSecureSocketOptions(int port, bool enableSsl) =>
        port == 465
            ? SecureSocketOptions.SslOnConnect // implicit TLS
            : enableSsl
                ? SecureSocketOptions.StartTls  // explicit TLS (STARTTLS)
                : SecureSocketOptions.None;
}
