using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.ApiExplorer;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.Swagger;

namespace AKA.CMS.API.Services;

/// <summary>
/// Builds a Postman Collection v2.1 document LIVE from the API's own OpenAPI
/// description — every endpoint, sample payload (from the DTO schemas),
/// headers and the Bearer auth setup. Always in sync: add an endpoint and
/// the downloaded collection contains it, no manual maintenance.
/// </summary>
public sealed partial class PostmanCollectionBuilder(
    ISwaggerProvider swaggerProvider,
    IApiDescriptionGroupCollectionProvider apiExplorer)
{
    public string BuildJson(HttpRequest request)
    {
        var doc = swaggerProvider.GetSwagger("v1");
        var anonymous = AnonymousRoutes();
        var baseUrl = $"{request.Scheme}://{request.Host}";

        var folders = new Dictionary<string, JsonArray>(StringComparer.OrdinalIgnoreCase);
        foreach (var (path, pathItem) in doc.Paths)
        {
            foreach (var (opType, operation) in pathItem.Operations)
            {
                var method = opType.ToString().ToUpperInvariant();
                var tag = operation.Tags.FirstOrDefault()?.Name ?? "General";
                if (!folders.TryGetValue(tag, out var items))
                    folders[tag] = items = new JsonArray();

                items.Add(BuildRequest(doc, method, path, operation,
                    isAnonymous: anonymous.Contains(RouteKey(method, path))));
            }
        }

        var collection = new JsonObject
        {
            ["info"] = new JsonObject
            {
                ["_postman_id"] = Guid.NewGuid().ToString(),
                ["name"] = doc.Info.Title,
                ["description"] = "Generated dynamically from the live OpenAPI description of this API. " +
                                  "Set the 'token' collection variable (or just call Auth > Login — it saves the token automatically).",
                ["schema"] = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
                ["version"] = doc.Info.Version
            },
            ["auth"] = new JsonObject
            {
                ["type"] = "bearer",
                ["bearer"] = new JsonArray
                {
                    new JsonObject { ["key"] = "token", ["value"] = "{{token}}", ["type"] = "string" }
                }
            },
            ["variable"] = new JsonArray
            {
                new JsonObject { ["key"] = "baseUrl", ["value"] = baseUrl, ["type"] = "string" },
                new JsonObject { ["key"] = "token", ["value"] = "", ["type"] = "string" }
            },
            ["item"] = new JsonArray(folders
                .OrderBy(f => f.Key, StringComparer.OrdinalIgnoreCase)
                .Select(f => (JsonNode)new JsonObject
                {
                    ["name"] = f.Key,
                    ["item"] = f.Value
                })
                .ToArray())
        };

        return collection.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
    }

    private JsonObject BuildRequest(OpenApiDocument doc, string method, string path,
        OpenApiOperation operation, bool isAnonymous)
    {
        var name = !string.IsNullOrWhiteSpace(operation.Summary)
            ? operation.Summary
            : $"{method} {path}";

        // ---- URL (path params -> :param + variable entries) ----
        var pathParams = new JsonArray();
        var postmanPath = PathParamPattern().Replace(path, m =>
        {
            var paramName = m.Groups[1].Value;
            pathParams.Add(new JsonObject
            {
                ["key"] = paramName,
                ["value"] = "1",
                ["description"] = $"{paramName} (path parameter)"
            });
            return ":" + paramName;
        });

        var url = new JsonObject
        {
            ["raw"] = "{{baseUrl}}" + postmanPath,
            ["host"] = new JsonArray("{{baseUrl}}"),
            ["path"] = new JsonArray(postmanPath.Trim('/').Split('/').Select(s => (JsonNode)JsonValue.Create(s)).ToArray())
        };
        if (pathParams.Count > 0) url["variable"] = pathParams;

        // ---- Query + header parameters ----
        var query = new JsonArray();
        var headers = new JsonArray
        {
            new JsonObject { ["key"] = "Accept", ["value"] = "application/json" }
        };
        foreach (var p in operation.Parameters)
        {
            var sample = SampleForSchema(p.Schema, p.Name);
            if (p.In == ParameterLocation.Query)
            {
                var q = new JsonObject
                {
                    ["key"] = p.Name,
                    ["value"] = sample?.ToString() ?? ""
                };
                if (!p.Required) q["disabled"] = true;
                if (!string.IsNullOrWhiteSpace(p.Description)) q["description"] = p.Description;
                query.Add(q);
            }
            else if (p.In == ParameterLocation.Header && !string.Equals(p.Name, "Authorization", StringComparison.OrdinalIgnoreCase))
            {
                headers.Add(new JsonObject { ["key"] = p.Name, ["value"] = sample?.ToString() ?? "" });
            }
        }
        if (query.Count > 0) url["query"] = query;

        var request = new JsonObject
        {
            ["method"] = method,
            ["header"] = headers,
            ["url"] = url
        };
        if (isAnonymous) request["auth"] = new JsonObject { ["type"] = "noauth" };
        if (!string.IsNullOrWhiteSpace(operation.Description)) request["description"] = operation.Description;

        // ---- Body ----
        if (operation.RequestBody?.Content is { Count: > 0 } content)
        {
            var media = content.ContainsKey("application/json")
                ? content["application/json"]
                : content.First().Value;
            var mediaType = content.ContainsKey("application/json") ? "application/json" : content.First().Key;

            headers.Add(new JsonObject { ["key"] = "Content-Type", ["value"] = mediaType });

            if (mediaType.Contains("multipart/form-data") || mediaType.Contains("x-www-form-urlencoded"))
            {
                var formKey = mediaType.Contains("multipart") ? "formdata" : "urlencoded";
                var entries = new JsonArray();
                var schema = Resolve(doc, media.Schema);
                if (schema?.Properties != null)
                {
                    foreach (var (propName, propSchema) in schema.Properties)
                    {
                        var resolved = Resolve(doc, propSchema);
                        var entry = new JsonObject { ["key"] = propName };
                        if (resolved?.Format == "binary" || resolved?.Type == "file")
                        {
                            entry["type"] = "file";
                            entry["src"] = "";
                        }
                        else
                        {
                            entry["type"] = "text";
                            entry["value"] = SampleForSchema(propSchema, propName)?.ToString() ?? "";
                        }
                        entries.Add(entry);
                    }
                }
                request["body"] = new JsonObject { ["mode"] = formKey, [formKey] = entries };
            }
            else
            {
                var sample = ExampleFromSchema(doc, media.Schema, depth: 0);
                request["body"] = new JsonObject
                {
                    ["mode"] = "raw",
                    ["raw"] = sample?.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) ?? "{}",
                    ["options"] = new JsonObject
                    {
                        ["raw"] = new JsonObject { ["language"] = "json" }
                    }
                };
            }
        }

        var item = new JsonObject
        {
            ["name"] = name,
            ["request"] = request,
            ["response"] = new JsonArray()
        };

        // Login convenience: save the access token into the collection variable.
        if (path.EndsWith("/auth/login", StringComparison.OrdinalIgnoreCase))
        {
            item["event"] = new JsonArray
            {
                new JsonObject
                {
                    ["listen"] = "test",
                    ["script"] = new JsonObject
                    {
                        ["type"] = "text/javascript",
                        ["exec"] = new JsonArray(
                            "if (pm.response.code === 200) {",
                            "    var data = pm.response.json();",
                            "    if (data.accessToken) pm.collectionVariables.set('token', data.accessToken);",
                            "}")
                    }
                }
            };
        }

        return item;
    }

    /// <summary>Routes marked [AllowAnonymous] — those requests get Postman 'noauth'.</summary>
    private HashSet<string> AnonymousRoutes()
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var group in apiExplorer.ApiDescriptionGroups.Items)
        foreach (var api in group.Items)
        {
            if (api.ActionDescriptor is not ControllerActionDescriptor cad) continue;
            var anonymous =
                cad.MethodInfo.GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AllowAnonymousAttribute), true).Length > 0 ||
                cad.ControllerTypeInfo.GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AllowAnonymousAttribute), true).Length > 0;
            if (anonymous && api.HttpMethod != null && api.RelativePath != null)
                set.Add(RouteKey(api.HttpMethod, "/" + NormalizeTemplate(api.RelativePath)));
        }
        return set;
    }

    private static string RouteKey(string method, string path) => method.ToUpperInvariant() + " " + NormalizeTemplate(path);

    /// <summary>"api/users/{id:int}" -> "api/users/{id}" for reliable matching.</summary>
    private static string NormalizeTemplate(string template)
        => RouteConstraintPattern().Replace(template.Trim(), "$1").TrimStart('/');

    private static OpenApiSchema? Resolve(OpenApiDocument doc, OpenApiSchema? schema)
    {
        if (schema?.Reference?.Id is { } id && doc.Components.Schemas.TryGetValue(id, out var resolved))
            return resolved;
        return schema;
    }

    private JsonNode? ExampleFromSchema(OpenApiDocument doc, OpenApiSchema? schema, int depth, string? propertyName = null)
    {
        if (schema == null || depth > 6) return JsonValue.Create("string");
        schema = Resolve(doc, schema);
        if (schema == null) return JsonValue.Create("string");
        if (schema.Example != null) return JsonNode.Parse(schema.Example.ToString() ?? "\"string\"") ?? JsonValue.Create("string");
        if (schema.Enum.Count > 0) return JsonNode.Parse(schema.Enum[0].ToString() ?? "\"string\"") ?? JsonValue.Create("string");

        switch (schema.Type)
        {
            case "object":
            case null when schema.Properties != null:
                var obj = new JsonObject();
                if (schema.Properties != null)
                    foreach (var (name, prop) in schema.Properties)
                        obj[name] = ExampleFromSchema(doc, prop, depth + 1, name);
                return obj;
            case "array":
                return new JsonArray(ExampleFromSchema(doc, schema.Items, depth + 1));
            case "integer":
                return JsonValue.Create(propertyName != null && propertyName.EndsWith("id", StringComparison.OrdinalIgnoreCase) ? 1 : 0);
            case "number":
                return JsonValue.Create(0.0);
            case "boolean":
                return JsonValue.Create(true);
            default:
                return JsonValue.Create(SampleForSchema(schema, propertyName)?.ToString() ?? "string");
        }
    }

    private static object? SampleForSchema(OpenApiSchema? schema, string? propertyName)
    {
        if (schema == null) return "string";
        var name = propertyName ?? "";
        return schema.Type switch
        {
            "integer" => name.EndsWith("id", StringComparison.OrdinalIgnoreCase) ? 1 : 0,
            "number" => 0,
            "boolean" => true,
            _ => schema.Format switch
            {
                "date-time" => "2026-01-01T10:00:00Z",
                "date" => "2026-01-01",
                "email" => "user@example.com",
                _ => name.ToLowerInvariant() switch
                {
                    "username" => "admin",
                    "password" or "newpassword" or "currentpassword" => "Test@1234",
                    var n when n.Contains("email") => "user@example.com",
                    var n when n.Contains("phone") => "03001234567",
                    _ => "string"
                }
            }
        };
    }

    [GeneratedRegex(@"\{([^}:]+)(?::[^}]+)?\}")]
    private static partial Regex PathParamPattern();

    [GeneratedRegex(@"\{([^}:]+)(?::[^}]+)?\}")]
    private static partial Regex RouteConstraintPattern();
}
