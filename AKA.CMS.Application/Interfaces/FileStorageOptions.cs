namespace AKA.CMS.Application.Interfaces;

public sealed class FileStorageOptions
{
    public const string SectionName = "FileStorage";

    public string UploadsPath { get; set; } = string.Empty;
}
