# SEO SPEC PART 4: STRUCTURED DATA SCHEMAS

## Organization (site-wide)
@type Organization, name mistaike.ai, founder Nick Stocks, description "MCP firewall and DLP gateway for AI agents"

## Homepage
@type SoftwareApplication, category SecurityApplication, offers Free tier 1000 req/day, featureList:
- MCP firewall bidirectional scanning
- DLP 90+ secrets 35+ PII
- Prompt injection 6 languages
- Destructive command guards
- URL scanning
- Audit trail
- MCP hub gateway

## Blog Posts
@type TechArticle with author Nick Stocks, publisher mistaike.ai

## Landing Pages
@type FAQPage with 4-6 genuine FAQs per page.

Key FAQ for /mcp-firewall:
- "What is an MCP firewall?" → "A security layer that sits between AI agents and MCP servers, scanning every tool call for secrets, PII, prompt injection, and destructive commands."
- "How is an MCP firewall different from an MCP gateway?" → "A gateway handles routing/auth/sessions. A firewall adds security scanning. mistaike.ai combines both."

## Breadcrumbs
BreadcrumbList schema on blog posts and docs pages.

## OG Tags (every page)
og:type, og:site_name, og:title, og:description, og:url, og:image + twitter:card summary_large_image.
Create 1200x630 OG image with dark bg, logo, "MCP Firewall & DLP Gateway".
