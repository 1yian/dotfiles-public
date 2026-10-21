// chrome-devtools-axi launches this with node. Keep its arguments intact and
// point the MCP at Home Manager's Chrome, not Puppeteer's hardcoded /opt path.
process.argv.push("--executablePath", `${process.env.HOME}/.nix-profile/bin/google-chrome`);
await import(`${process.env.HOME}/.local/lib/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js`);
