/**
 * Pure Code 128 (Subset B) Barcode Generator.
 * Encodes standard printable ASCII characters (32..126) without external dependencies.
 * Generates crisp vector SVG paths/rectangles suitable for both screen preview and thermal/sheet printing.
 */

// ISO/IEC 15417 Code 128 symbol patterns (alternating widths of bars and spaces).
export const CODE128_PATTERNS = [
  "212222", "222122", "222221", "121223", "121322", "131222", "122213", "122312", "132212", "221213",
  "221312", "231212", "112232", "122132", "122231", "113222", "123122", "123221", "223211", "221132",
  "221231", "213212", "223112", "312131", "311222", "321122", "321221", "312212", "322112", "322211",
  "212123", "212321", "232121", "111323", "131123", "131321", "112313", "132113", "132311", "211313",
  "231113", "231311", "112133", "112331", "132131", "113123", "113321", "133121", "313121", "211331",
  "231131", "213113", "213311", "213131", "311123", "311321", "331121", "312113", "312311", "332111",
  "314111", "221411", "431111", "111224", "111422", "121124", "121421", "141122", "141221", "112214",
  "112412", "122114", "122411", "142112", "142211", "241211", "221114", "413111", "241112", "134111",
  "111242", "121142", "121241", "114212", "124112", "124211", "411212", "421112", "421211", "212141",
  "214121", "412121", "111143", "111341", "131141", "114113", "114311", "411113", "411311", "113141",
  "114131", "311141", "411131", "211412", "211214", "211232", "2331112"
];

export const START_CODE_B = 104;
export const STOP_CODE = 106;

export interface EncodedBar {
  x: number;
  width: number;
}

export interface BarcodeResult {
  bars: EncodedBar[];
  totalModules: number;
  checksum: number;
  rawText: string;
}

/**
 * Encodes a text string into Code 128B barcode bars.
 * Characters outside ASCII 32..126 are filtered out.
 */
export function encodeCode128(text: string, quietZoneModules = 10): BarcodeResult {
  const clean = text.replace(/[^\x20-\x7E]/g, "");
  const codeVals: number[] = [];

  for (let i = 0; i < clean.length; i++) {
    codeVals.push(clean.charCodeAt(i) - 32);
  }

  // Calculate Checksum: (START + SUM(i * codeVal)) % 103
  let sum = START_CODE_B;
  for (let i = 0; i < codeVals.length; i++) {
    sum += (i + 1) * (codeVals[i] ?? 0);
  }
  const checksum = sum % 103;

  // Complete symbol list: Start B -> Symbols -> Checksum -> Stop
  const allSymbols = [START_CODE_B, ...codeVals, checksum, STOP_CODE];

  const bars: EncodedBar[] = [];
  let currentModule = quietZoneModules;

  for (const sym of allSymbols) {
    const pattern = CODE128_PATTERNS[sym];
    if (!pattern) continue;

    for (let k = 0; k < pattern.length; k++) {
      const width = parseInt(pattern[k] ?? "1", 10);
      const isBar = k % 2 === 0;
      if (isBar) {
        bars.push({
          x: currentModule,
          width,
        });
      }
      currentModule += width;
    }
  }

  const totalModules = currentModule + quietZoneModules;

  return {
    bars,
    totalModules,
    checksum,
    rawText: clean,
  };
}

export interface BarcodeSvgProps {
  value: string;
  height?: number;
  showText?: boolean;
  className?: string;
}

/**
 * Clean SVG Barcode component using Code 128.
 */
export function BarcodeSvg({
  value,
  height = 40,
  showText = true,
  className = "",
}: BarcodeSvgProps) {
  const encoded = encodeCode128(value);
  const textHeight = showText ? 14 : 0;
  const totalSvgHeight = height + textHeight;

  return (
    <svg
      viewBox={`0 0 ${encoded.totalModules} ${totalSvgHeight}`}
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      preserveAspectRatio="none"
      style={{ display: "block", width: "100%", height: "auto", maxHeight: `${totalSvgHeight}px` }}
    >
      <g fill="currentColor">
        {encoded.bars.map((bar, idx) => (
          <rect
            key={idx}
            x={bar.x}
            y={0}
            width={bar.width}
            height={height}
          />
        ))}
      </g>
      {showText && encoded.rawText ? (
        <text
          x={encoded.totalModules / 2}
          y={height + 11}
          textAnchor="middle"
          fill="currentColor"
          fontSize="10"
          fontFamily="ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"
          fontWeight="600"
          letterSpacing="1"
        >
          {encoded.rawText}
        </text>
      ) : null}
    </svg>
  );
}
