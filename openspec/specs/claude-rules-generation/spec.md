# claude-rules-generation Specification

## Purpose
Analyze a repository or folder from a chosen scan root (git optional) and, interactively with the
user, build evidence-backed, path-scoped Claude rule files under `.claude/rules/` — each carrying
frontmatter for contextual loading — whose rules are inferred from observed structure, recurring
code patterns, and declared config signals, confirmed by the user, never invented, and reconciled
against any existing rule files rather than overwriting them.

## Requirements

### Requirement: Scan-root establishment (git optional)

The skill SHALL establish a scan root that gives it whole-tree context, and SHALL work whether or
not the target is a git repository. In a git work tree it SHALL default the scan root to the
resolved repository root (e.g. `git rev-parse --show-toplevel`), scanning from there even when
invoked in a subdirectory and telling the user which root it chose; a bare `.git` name check SHALL
NOT be used as the sole marker, because `.git` is a directory in a normal checkout but a file in a
linked worktree or submodule. When the target is not a git repository, the scan root SHALL be the
current directory (or an explicit path the user gives), and the skill SHALL NOT refuse. If the user
explicitly scopes analysis to a subtree, the skill MAY proceed against that subtree and SHALL
record the reduced scope in every rule it writes.

#### Scenario: Invoked in a git work tree

- **WHEN** the skill is invoked inside a git work tree, at the root or in a subdirectory (including a linked worktree or submodule root, where `.git` is a file rather than a directory)
- **THEN** the skill sets the scan root to the resolved repository root and proceeds, telling the user which root it chose

#### Scenario: Invoked in a non-git folder

- **WHEN** the skill is invoked in a directory that is not a git repository
- **THEN** the skill uses that directory (or an explicit path the user gives) as the scan root and proceeds without refusing

#### Scenario: Subtree override records reduced scope

- **WHEN** the user explicitly scopes analysis to a subtree
- **THEN** the skill proceeds against that subtree and records the reduced scope in every rule it writes

### Requirement: Scannable file set and ignore layering

The skill SHALL derive its analysis set from an enumeration source with build/vendored noise
excluded, and SHALL support excluding tracked-but-irrelevant directories. In a git work tree it
SHALL enumerate from tracked files (e.g. `git ls-files`); without git it SHALL walk the tree honoring
any `.gitignore` present plus a bundled default ignore list (dependency, build-output, and vendored
directories). In both modes it SHALL additionally subtract patterns from a user-global
(`~/.claude/rules-ignore`) then a repo-local (`.claude/rules-ignore`) ignore file, in `.gitignore`
syntax, so large tracked directories irrelevant to scanning are excluded. The skill SHALL report the
top-level directories it excluded.

#### Scenario: Tracked-but-irrelevant directory excluded via rules-ignore

- **WHEN** a `.claude/rules-ignore` (or `~/.claude/rules-ignore`) file lists a tracked directory
- **THEN** the skill excludes that directory from analysis even in a git work tree, and reports it as excluded

#### Scenario: Non-git enumeration honors default and gitignore excludes

- **WHEN** the skill runs without git
- **THEN** it walks the tree excluding entries matched by any present `.gitignore` and by its bundled default ignore list

### Requirement: Whole-repo structural and pattern analysis

The skill SHALL characterize the repository using whole-repo context: the directory tree, module
layering, file/naming conventions, test placement, and error-handling idioms. Where language
tooling is available, it SHALL use symbol/LSP capabilities to observe recurring code patterns
from actual usage rather than from a single sampled file. It SHALL handle multi-language and
monorepo layouts by attributing patterns to the subtree/package they hold in, not assuming one
convention for the whole tree.

#### Scenario: Monorepo with divergent per-package conventions

- **WHEN** the repository is a monorepo whose packages use different conventions (e.g. one package uses one test layout and another uses a different one)
- **THEN** the proposed rules attribute each convention to the package/subtree it was observed in rather than asserting a single repo-wide convention

#### Scenario: Polyglot repository

- **WHEN** the repository contains more than one primary language (e.g. a backend and a frontend in different languages)
- **THEN** the analysis covers each language's subtree and the proposed rules reflect each language's observed conventions

### Requirement: Interactive, user-confirmed rule building

The skill SHALL build the ruleset interactively with the user rather than emitting rules
non-interactively. It SHALL walk the repository with the user, present each observed candidate
pattern together with its supporting evidence, and ask the user to confirm whether it is a real
convention, what the rule should say, and which paths/subtrees it applies to. A rule SHALL be
written only after the user confirms it; patterns the user rejects SHALL NOT be written as rules.

#### Scenario: Observed pattern is presented for confirmation

- **WHEN** the skill identifies a recurring candidate pattern in the repository
- **THEN** it presents that pattern and its evidence to the user and asks whether it is a real convention, how to phrase the rule, and where it applies

#### Scenario: User rejects a candidate pattern

- **WHEN** the user indicates a presented candidate pattern is not a convention to enforce
- **THEN** the skill does not write a rule for that pattern

#### Scenario: User narrows where a rule applies

- **WHEN** the user says a confirmed rule applies only to a specific subtree or path set
- **THEN** the written rule's scope reflects exactly that path set, not the whole repository

### Requirement: Evidence-backed rules only

Every proposed rule SHALL cite the concrete evidence it was inferred from — the files, symbols,
or config it observed. A rule that has no observed support in the repository SHALL NOT be
emitted. The skill SHALL NOT invent conventions the codebase does not exhibit. Evidence is
necessary but not sufficient: a candidate that is well-evidenced but that Claude would already
honor unprompted — a standard language idiom, or anything plainly visible in the files it edits —
SHALL NOT be emitted as a rule (it is documentation, not a rule).

#### Scenario: Rule carries its supporting evidence

- **WHEN** the skill proposes a rule about a convention
- **THEN** that rule is accompanied by a citation of the concrete repository evidence (paths, symbols, or config) it was inferred from

#### Scenario: Unsupported convention is withheld

- **WHEN** a candidate convention has no observable support anywhere in the repository
- **THEN** the skill does not emit a rule asserting that convention

#### Scenario: Obvious convention withheld despite evidence

- **WHEN** a candidate convention is well-evidenced but Claude would already follow it unprompted (a standard language idiom, or something plainly visible in the files it edits)
- **THEN** the skill does not emit a rule for it, treating it as documentation rather than a rule

### Requirement: Reconciliation with declared config signals

The skill SHALL detect declared configuration signals (such as linter, formatter, type-checker,
and editor config files) and SHALL prefer an enforced/declared convention over a convention only
inferred from code when the two describe the same concern. Declared conventions MAY also be read
from already-written convention docs (`README`/`CONTRIBUTING`) and other agents' rule files
(`.cursor/rules`, `.cursorrules`, `AGENTS.md`, `.github/copilot-instructions.md`); these are read as
evidence only — the skill still writes Claude rules exclusively and never edits another agent's
file. Where an observed code pattern conflicts with a declared config signal, the skill SHALL
surface the conflict rather than silently choosing one.

#### Scenario: Declared config outweighs inferred style

- **WHEN** a formatter/linter config declares a convention and code broadly follows it
- **THEN** the proposed rule reflects the declared convention and cites the config as its source

#### Scenario: Code contradicts declared config

- **WHEN** an observed code pattern conflicts with a declared config signal for the same concern
- **THEN** the skill reports the conflict to the user instead of silently emitting one side as a rule

#### Scenario: Other agents' rule files are read as evidence only

- **WHEN** the repository contains another agent's rule file (e.g. `.cursor/rules` or `AGENTS.md`)
- **THEN** the skill may use its stated conventions as evidence but writes only Claude rules and never edits the other agent's file

### Requirement: Output follows Claude Code's documented rule placement

The skill SHALL place rules using Claude Code's documented mechanism. Path-specific or
single-area conventions SHALL be written as rule files under the repository's `.claude/rules/`
directory (creating it if absent). Genuinely repo-wide standards MAY instead be placed in the
repository's `CLAUDE.md` (or `.claude/CLAUDE.md`). The skill SHALL NOT place path-specific or
single-area guidance in `CLAUDE.md`, and SHALL report every path it wrote.

#### Scenario: Path-specific rule goes to .claude/rules

- **WHEN** a confirmed rule applies only to a specific subtree or file pattern
- **THEN** the skill writes it as a rule file under `.claude/rules/`, not into `CLAUDE.md`
- **AND** it reports the path it wrote to

#### Scenario: Repo-wide standard may go to CLAUDE.md

- **WHEN** a confirmed rule is a repository-wide standard that applies everywhere
- **THEN** the skill MAY place it in `CLAUDE.md` (or `.claude/CLAUDE.md`) as a concise entry, or as a launch-loaded rule file under `.claude/rules/`

### Requirement: Path-scoped rule files use `paths:` frontmatter

For a rule that applies only to part of the repository, the skill SHALL write it as a
`.claude/rules/` file carrying a `paths:` frontmatter list of globs covering the area it was
confirmed to apply to — the documented mechanism by which Claude loads the rule only when it
reads files matching those globs. A rule intended to be always in effect SHALL omit `paths:` (so
it loads at launch). The `paths:` globs SHALL match where the rule was confirmed to apply, not
unrelated paths. Each rule file SHALL be a `.md` file kebab-case named after its concern, with YAML
frontmatter delimited by `---` carrying the `paths:` list and the rule under a body heading. Globs
SHALL be anchored so a whole-subtree scope also matches files directly in the subtree root (pairing
a top-level glob with a recursive one, e.g. `dir/*.{ts,tsx}` and `dir/**/*.{ts,tsx}`), rather than a
bare `dir/**` that would load the rule for every file in the subtree.

#### Scenario: Subtree rule carries matching `paths:` globs

- **WHEN** the skill writes a rule confirmed to apply only to a specific subtree
- **THEN** the rule file's frontmatter includes a `paths:` list of globs covering that subtree and not unrelated paths

#### Scenario: Always-on rule omits `paths:`

- **WHEN** the skill writes a rule intended to apply everywhere via a launch-loaded rule file
- **THEN** that rule file omits `paths:` frontmatter so it loads at launch

### Requirement: Non-destructive merge with existing rules

The skill SHALL merge or update existing rules rather than overwriting them wholesale when a
target it writes to — files under `.claude/rules/` or an existing `CLAUDE.md` — already has
content, and SHALL flag any conflict between an existing rule and the reality observed in the
repository. When a rule file already covers the same concern, the skill SHALL edit that file —
unioning the new `paths:` globs into its frontmatter list and revising the matching body section in
place rather than appending a duplicate — and SHALL add a new sibling file only when no existing
file covers the concern, leaving unrelated files and sections untouched.

#### Scenario: Existing rule files are merged, not clobbered

- **WHEN** `.claude/rules/` already contains rule files with prior content
- **THEN** the skill updates/merges them, preserving still-valid existing rules rather than replacing them wholesale

#### Scenario: Existing CLAUDE.md is appended to, not replaced

- **WHEN** the skill adds a repo-wide standard and a `CLAUDE.md` already exists
- **THEN** the skill merges the entry into the existing file rather than overwriting the file

#### Scenario: Existing rule contradicts observed reality

- **WHEN** an existing rule contradicts what the skill observes in the current code
- **THEN** the skill flags that contradiction for the user rather than silently keeping or deleting the rule
