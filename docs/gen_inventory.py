#!/usr/bin/env python3
"""Generate docs/API_INVENTORY.md from the API controllers.

Scans AKA.CMS.API/Controllers/*.cs with a simple line-based parser and
emits a markdown table of every endpoint: HTTP method, route, auth policy,
documented response codes, and the XML summary.
Run from the repo root:  python3 docs/gen_inventory.py
"""
import os
from datetime import date

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CTRL = os.path.join(REPO, "AKA.CMS.API", "Controllers")
OUT = os.path.join(REPO, "docs", "API_INVENTORY.md")

HTTP_ATTRS = ("HttpGet", "HttpPost", "HttpPut", "HttpDelete", "HttpPatch")


def clean(s):
    return " ".join(s.split())


def parse_controller(path):
    with open(path) as f:
        lines = [l.rstrip("\n") for l in f]

    class_route, class_summary = "", ""
    class_decl_idx = next(
        (idx for idx, l in enumerate(lines)
         if "class " in l and "Controller(" in l),
        len(lines))
    class_anon = any(
        l.strip() == "[AllowAnonymous]" for l in lines[:class_decl_idx])
    for i, l in enumerate(lines[:class_decl_idx]):
        s = l.strip()
        if s.startswith("[Route("):
            inner = s[len("[Route("):].strip()
            if inner.endswith(")]"):
                inner = inner[:-2]
            class_route = inner.strip('"')
        if s == "[ApiController]" and i > 0:
            prev = lines[i - 1].strip()
            if prev.startswith("/// <summary>"):
                class_summary = clean(
                    prev[len("/// <summary>"):].split("</summary>")[0])

    endpoints = []
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        verb = next((h for h in HTTP_ATTRS if s.startswith("[" + h)), None)
        if verb:
            # walk back over the attribute/summary block above
            j = i - 1
            summary, codes, policies = "", [], []
            anon = False
            while j >= 0:
                t = lines[j].strip()
                if t.startswith("/// <summary>"):
                    summary = clean(
                        t[len("/// <summary>"):].split("</summary>")[0])
                elif t.startswith("[ProducesResponseType("):
                    code = t.split("StatusCodes.")[1].split(",")[0].split(")")[0]
                    codes.append(code)
                elif t.startswith("[Authorize(Policy = "):
                    policies.append(
                        t[len("[Authorize(Policy = "):].rstrip(")]"))
                elif t == "[AllowAnonymous]":
                    anon = True
                elif t.startswith("[") or t == "":
                    pass
                else:
                    break
                j -= 1
            template = ""
            if "(" in s:
                template = s.split('("', 1)[1].rsplit('")', 1)[0] \
                    if '("' in s else ""
            if template.startswith("api/") or not class_route:
                route = template
            else:
                route = (class_route + "/" + template).rstrip("/")
            route = "/" + route.lstrip("/")
            # find the action name + method-level auth on the following lines
            k = i + 1
            while k < len(lines):
                t = lines[k].strip()
                if t.startswith("public "):
                    break
                if t.startswith("[Authorize(Policy = "):
                    policies.append(t[len("[Authorize(Policy = "):].rstrip(")]"))
                elif t == "[AllowAnonymous]":
                    anon = True
                elif t.startswith("[ProducesResponseType("):
                    code = t.split("StatusCodes.")[1].split(",")[0].split(")")[0]
                    codes.append(code)
                k += 1
            action = ""
            if k < len(lines):
                sig = clean(" ".join(lines[k:k + 3]))
                if "(" in sig:
                    action = sig.split("(")[0].split()[-1]
            codes.reverse()
            endpoints.append({
                "verb": verb[4:].upper(),
                "route": route,
                "auth": "anonymous" if (anon or class_anon) else (policies[0] if policies else "authenticated"),
                "codes": ", ".join(codes),
                "summary": summary,
                "action": action,
            })
        i += 1
    return class_route, class_summary, endpoints


def main():
    files = sorted(f for f in os.listdir(CTRL) if f.endswith("Controller.cs"))
    total = 0
    sections = []
    for fname in files:
        cname = fname[:-3]
        class_route, class_summary, endpoints = parse_controller(
            os.path.join(CTRL, fname))
        total += len(endpoints)
        parts = [f"### {cname} — `{class_route or '(action-level routes)'}`"]
        if class_summary:
            parts.append(f"*{class_summary}*")
        parts.append("")
        parts.append("| Method | Route | Auth | Responses | Description |")
        parts.append("|---|---|---|---|---|")
        for e in endpoints:
            desc = e["summary"].replace("|", "\\|")
            parts.append(
                f"| {e['verb']} | `{e['route']}` | {e['auth']} | "
                f"{e['codes']} | {desc} |")
        parts.append("")
        sections.append("\n".join(parts))

    doc = f"""# AKA-CMS API Inventory

Auto-generated from `AKA.CMS.API/Controllers/` by `docs/gen_inventory.py`.
Do not edit by hand — re-run the script after controller changes.

- Generated: {date.today().isoformat()}
- Controllers: {len(files)}
- Endpoints: {total}
- Auth: every endpoint except `POST /api/auth/login`, `POST /api/auth/refresh`
  and `GET /api/health` requires a JWT Bearer token; the `Auth` column names
  the permission policy (resolved from the `RolePermissions` table at startup).
- Error payloads are RFC 7807 `application/problem+json`.

""" + "\n".join(sections)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write(doc)
    print(f"Wrote {OUT}: {len(files)} controllers, {total} endpoints")


if __name__ == "__main__":
    main()
