// Generates CSS variables / Tailwind @theme mappings and Flutter tokens from docs/tokens.json.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");
const tokens = JSON.parse(readFileSync(resolve(root, "docs/tokens.json"), "utf8"));

const camelToKebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").replace(/([a-zA-Z])(\d+)/g, "$1-$2").toLowerCase();

const cssVars = Object.entries(tokens.color)
  .map(([k, v]) => `  --${camelToKebab(k)}: ${v};`)
  .join("\n");

const themeColors = Object.entries(tokens.color)
  .map(([k]) => {
    const kebab = camelToKebab(k);
    return `  --color-${kebab}: var(--${kebab});`;
  })
  .join("\n");

const radiusVars = Object.entries(tokens.radius)
  .map(([k, v]) => `  --nm-radius-${camelToKebab(k)}: ${v}px;`)
  .join("\n");

const sizeVars = Object.entries(tokens.size)
  .map(([k, v]) => `  --nm-size-${camelToKebab(k)}: ${v}px;`)
  .join("\n");

const touchVars = Object.entries(tokens.touch)
  .map(([k, v]) => `  --nm-touch-${camelToKebab(k)}: ${v}px;`)
  .join("\n");

const cssOut = `/* GENERATED FROM docs/tokens.json — DO NOT EDIT BY HAND. Run node scripts/generate-design-tokens.mjs */
:root {
${cssVars}
${radiusVars}
${sizeVars}
${touchVars}
  --nm-border-w: ${tokens.border}px;
}

@theme {
${themeColors}
  --font-display: "Bricolage Grotesque", Inter, system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, SFMono-Regular, monospace;
}
`;

mkdirSync(resolve(root, "apps/client/src/styles"), { recursive: true });
writeFileSync(resolve(root, "apps/client/src/styles/tokens.generated.css"), cssOut);

const tsTokens = `// GENERATED FROM docs/tokens.json — DO NOT EDIT BY HAND. Run node scripts/generate-design-tokens.mjs
export const DESIGN_TOKENS = {
  color: {
${Object.keys(tokens.color)
  .map((k) => `    ${k}: "var(--${camelToKebab(k)})",`)
  .join("\n")}
  },
  size: ${JSON.stringify(tokens.size)},
  space: ${JSON.stringify(tokens.space)},
  radius: ${JSON.stringify(tokens.radius)},
  border: ${JSON.stringify(tokens.border)},
  touch: ${JSON.stringify(tokens.touch)},
} as const;
`;

mkdirSync(resolve(root, "apps/client/src/ui"), { recursive: true });
writeFileSync(resolve(root, "apps/client/src/ui/tokens.ts"), tsTokens);

const toDartColor = (hex) => {
  const clean = hex.replace("#", "").toUpperCase();
  return `Color(0xFF${clean})`;
};

const dartOut = `// GENERATED FROM docs/tokens.json — DO NOT EDIT BY HAND. Run node scripts/generate-design-tokens.mjs
import 'package:flutter/material.dart';

abstract final class DesignTokens {
${Object.entries(tokens.color)
  .map(([k, v]) => `  static const Color ${k} = ${toDartColor(v)};`)
  .join("\n")}

  static const double borderWidth = ${Number(tokens.border).toFixed(1)};
  static const List<double> space = <double>[${tokens.space.map((n) => `${n}.0`).join(", ")}];

${Object.entries(tokens.size)
  .map(([k, v]) => `  static const double size${k[0].toUpperCase()}${k.slice(1)} = ${Number(v).toFixed(1)};`)
  .join("\n")}

${Object.entries(tokens.radius)
  .map(([k, v]) => `  static const double radius${k[0].toUpperCase()}${k.slice(1)} = ${Number(v).toFixed(1)};`)
  .join("\n")}

${Object.entries(tokens.touch)
  .map(([k, v]) => `  static const double touch${k[0].toUpperCase()}${k.slice(1)} = ${Number(v).toFixed(1)};`)
  .join("\n")}
}
`;

writeFileSync(resolve(root, "apps/mobile/lib/core/design_tokens.g.dart"), dartOut);
console.log("Generated tokens.generated.css, src/ui/tokens.ts, and design_tokens.g.dart from docs/tokens.json");
