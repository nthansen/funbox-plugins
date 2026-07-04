import { readFileSync } from 'node:fs';

// Doc globs. `**/` is an optional prefix (matches root and nested); `**` at the tail
// matches everything under a dir. Kept consistent with the audience-rules base
// (all *.md under .claude/ are Claude-facing docs).
export const DEFAULT_DOC_PATTERNS = [
  '**/CLAUDE*.md',
  '**/README*.md',
  '**/CHANGELOG.md',
  'docs/**',
  '**/docs/**',
  '.claude/**/*.md',
  '**/.claude/**/*.md',
];

// First-party changes that do not require docs (distinct from excludeDirs, which is vendored).
// Evaluated after excludeDirs and before docPatterns. Default: common test files.
export const DEFAULT_EXEMPT_PATTERNS = [
  '**/*.test.*',
  '**/*.spec.*',
  '**/test/**',
  '**/tests/**',
  '**/__tests__/**',
  '**/*_test.go',
  '**/*_test.py',
];

// Translate a glob to an anchored RegExp. Supported: `**/` (optional dir prefix),
// `**` (across segments), `*` (within one segment), literals. No braces/char-classes.
export function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*' && glob[i + 1] === '*') {
      i++; // consume second *
      if (glob[i + 1] === '/') { i++; re += '(?:.*/)?'; } // **/ -> optional dir prefix
      else re += '.*';                                     // ** -> anything incl. /
    } else if (c === '*') {
      re += '[^/]*';
    } else if ('.+^${}()|[]\\/'.includes(c)) {
      re += '\\' + c;
    } else {
      re += c;
    }
  }
  return new RegExp('^' + re + '$');
}

export function classify(files, { docPatterns, excludeDirs, exemptPatterns } = {}) {
  const docRes = ((docPatterns && docPatterns.length) ? docPatterns : DEFAULT_DOC_PATTERNS).map(globToRegExp);
  const exemptRes = ((exemptPatterns && exemptPatterns.length) ? exemptPatterns : DEFAULT_EXEMPT_PATTERNS).map(globToRegExp);
  const excludes = (excludeDirs || []).map((ex) => ex.replace(/\/+$/, ''));
  const nonDoc = [];
  let docChanged = false;
  for (const f of files) {
    if (!f) continue;
    if (excludes.some((ex) => f === ex || f.startsWith(ex + '/'))) continue; // excluded (vendored)
    if (exemptRes.some((r) => r.test(f))) continue;                          // exempt (e.g. tests)
    if (docRes.some((r) => r.test(f))) docChanged = true;                    // documentation
    else nonDoc.push(f);                                                     // doc-requiring
  }
  return { nonDoc, docChanged };
}

function main() {
  const argv = process.argv.slice(2);
  let cfgPath = null;
  for (let i = 0; i < argv.length; i++) if (argv[i] === '--config') cfgPath = argv[++i];
  let opts = {};
  if (cfgPath) {
    try {
      const c = JSON.parse(readFileSync(cfgPath, 'utf8'));
      opts = { docPatterns: c.docPatterns, excludeDirs: c.excludeDirs, exemptPatterns: c.exemptPatterns };
    } catch { /* fall back to defaults */ }
  }
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (d) => (input += d));
  process.stdin.on('end', () => {
    const files = input.split('\n').map((s) => s.trim()).filter(Boolean);
    process.stdout.write(JSON.stringify(classify(files, opts)));
  });
}

// Run as CLI only when invoked directly (not when imported by tests).
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('doc-classify.mjs')) {
  main();
}
