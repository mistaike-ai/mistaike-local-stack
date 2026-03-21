# SEO SPEC PART 6: INTERNAL LINKING, SITEMAP & TECHNICAL SEO

## Internal Linking Rules
- `/` links to: /mcp-firewall, /mcp-gateway, /sandboxed-mcp, /memory-migration, /blog, /docs/mcp-setup, /pricing
- `/mcp-firewall` links to: /, /mcp-gateway, /sandboxed-mcp, /docs/mcp-setup, /pricing, blog posts
- `/mcp-gateway` links to: /, /mcp-firewall, /sandboxed-mcp, /docs/mcp-setup, /pricing, blog posts
- `/sandboxed-mcp` links to: /, /mcp-firewall, /mcp-gateway, /docs/mcp-setup, /pricing
- `/memory-migration` links to: /, /mcp-gateway, /docs/mcp-setup, /pricing
- Every blog post: 2+ internal links to product/landing pages. Use keyword-rich anchor text.

## Sitemap
Remove all 32 sitemap-patterns-*.xml from index. Create sitemap-pages.xml with ~12 core pages only.

Priority:
- `/` at 1.0
- Landing pages 0.9
- Blog/pricing/docs 0.8
- About/changelog 0.4-0.5

Let Google discover /patterns via internal links instead.

## Technical SEO
- Canonical URLs on every page
- Consistent no-trailing-slash
- All images need alt text with keywords
- WebP format
- Lazy-load below fold
- Semantic HTML (article, nav, main, section)
- `lang="en"` on html tag

Canonical URL format: `<link rel="canonical" href="https://mistaike.ai/{path}" />`

## Nav Restructure Suggestion
Products dropdown (MCP Firewall, MCP Gateway, Sandboxed MCP, Memory Migration) | Docs dropdown (API Docs, MCP Setup) | Pricing | Blog
