# Documentation Completion Plan

Audit date: 2026-06-30
Scope: all `.md` files, Dart `///` doc comments in `app_flutter/lib/`

---

## 1. Documentation Backlog

| Doc | Lines | Status | Missing Content | Est. Effort | Agent |
|-----|-------|--------|----------------|-------------|-------|
| `README.md` (repo root) | 456 | EXISTS but no ToC | Add table of contents, quick-start badge, link to docs/ | Small | Agent A |
| `app_flutter/README.md` | 17 | EXISTS - generic Flutter template | Replace with project-specific: architecture overview, key domain types, data sources, build/run commands | Medium | Agent B |
| `app_test_harness/README.md` | 17 | EXISTS - generic Flutter template | Replace with project-specific: purpose (test harness for what), relationship to app_flutter, run instructions | Small | Agent B |
| `docs/operations/install-guide.md` | 0 | **MISSING** | Prerequisites (Python 3, Flutter SDK, Node, Java), full clone/build/run flow, platform selection, environment variables | Medium | Agent C |
| `docs/operations/api-reference.md` | 0 | **MISSING** | Document public Dart API surface: domain types, data sources, layout components, view models. Auto-generated or hand-curated reference | Large | Agent D |
| `docs/operations/domain-deployment.md` | 729 | EXISTS, good quality | Has ToC, prerequisites, steps, examples, troubleshooting. Verify file paths referenced (assets/properties_db.db, scripts) are still accurate | Small | Agent C |
| `docs/operations/firebase-configuration.md` | 448 | EXISTS, good quality | Has ToC, prerequisites, local/cloud modes, data model, seeding, troubleshooting. Verify script paths exist | Small | Agent C |
| `docs/operations/yang-compiler-guide.md` | 856 | EXISTS, good quality | Has ToC, overview, installation, usage, mapping reference, integration, examples, limitations, troubleshooting. Verify pyang version compatibility | Small | Agent C |
| `docs/process/feature-driven-workflow.md` | 71 | EXISTS | Links to `skills/feature-driven-implementation/SKILL.md` - verify that file exists and link is correct | Small | Agent A |
| `docs/use-cases/uc-*.md` (6 files) | 54-104 each | EXISTS | All have standard use-case template. Verify file paths and references to `docs/features/` are current | Small | Agent A |

### Summary: Documentation Gaps
- **Missing**: `install-guide.md`, `api-reference.md`
- **Needs rewrite**: `app_flutter/README.md`, `app_test_harness/README.md`
- **Needs minor updates**: root `README.md` (add ToC), operational docs (verify paths)

---

## 2. Code Documentation Backlog

Files in `app_flutter/lib/` sorted by priority (largest undocumented first):

| File | Lines | Public APIs | Has `///`? | Missing Coverage | Est. Effort | Agent |
|------|-------|-------------|------------|------------------|-------------|-------|
| `features/properties/property_grid.dart` | 622 | 3 classes | **NO** | `UpperCaseTextFormatter`, `PropertyGrid`, `_PropertyGridState` - all public members undocumented | Medium | Agent X |
| `features/topology/topology_map.dart` | 686 | 8 types | PARTIAL (9 blocks) | `TopologyPainter`, `NodePosition`, many methods lack docs | Medium | Agent X |
| `features/layout/layout.dart` | 316 | 2 classes | PARTIAL (1 block) | Classes `LayoutConfig`, layout widgets missing docs | Medium | Agent X |
| `features/layout/component_factory.dart` | 227 | 5 types | PARTIAL (2 blocks) | Factory functions, component types need docs | Medium | Agent X |
| `features/layout/breadcrumbs.dart` | 197 | 3 types | PARTIAL (10 blocks) | `BreadcrumbOverflow`, `_BreadcrumbOverflowState` have some docs, verify completeness | Small | Agent X |
| `domain/database_initializer.dart` | 202 | 1 class | **NO** | `DatabaseInitializer` and all public methods | Small | Agent X |
| `features/tree/view_models/tree_view_model.dart` | 243 | 1 class | **NO** | `TreeViewModel`, all public methods/properties | Medium | Agent Y |
| `features/layout/split_workspace.dart` | 133 | 2 types | **NO** | `SplitWorkspace`, `_SplitWorkspaceState` | Small | Agent Y |
| `features/tree/sidebar_tree.dart` | 142 | 1 class | **NO** | `SidebarTree` widget and all methods | Small | Agent Y |
| `features/topology/topographical_view.dart` | 80 | 1 class | **NO** | `TopographicalView` | Small | Agent Y |
| `features/layout/layout_config_service.dart` | 49 | 0 types | **NO** | No types declared; if service class exists, needs docs | Small | Agent Y |
| `features/tree/tree_node_widget.dart` | 86 | 1 class | **NO** | `TreeNodeWidget` | Small | Agent Y |
| `features/tables/table_view_widget.dart` | 77 | 1 class | **NO** | `TableViewWidget` | Small | Agent Y |
| `features/properties/view_models/properties_view_model.dart` | 17 | 1 class | **NO** | `PropertiesViewModel` | Small | Agent Y |
| `domain/repository_resolver.dart` | 104 | 1 class | **NO** | `RepositoryResolver`, all methods | Small | Agent Y |
| `domain/schema.dart` | 55 | 1 class | **NO** | Schema-related class | Small | Agent Y |
| `domain/data_sources/firebase_data_source.dart` | 149 | 1 class | **NO** | `FirebaseDataSource` | Medium | Agent Y |
| `app/app.dart` | 88 | 3 classes | **NO** | `App`, app-level classes | Small | Agent Y |
| `core/background_worker.dart` | 52 | 1 class | **NO** | `BackgroundWorker` | Small | Agent Y |
| `main.dart` | 62 | 0 types | **NO** | Entry point; `void main()` should have doc comment | Small | Agent Y |

### Summary: Code Documentation Gaps
- **12 files have zero `///` doc comments** (listed above as "NO")
- **Largest undocumented files**: `property_grid.dart` (622 lines, 3 classes), `tree_view_model.dart` (243 lines), `component_factory.dart` (227 lines)
- **Domain layer**: 3 files need docs (database_initializer, repository_resolver, schema, firebase_data_source)
- **Feature layer**: Most view models, widgets, and layout components need full doc coverage
- **Total effort**: ~medium (15 small + 5 medium items)

### Already Well-Documented Files (maintain only)

| File | Lines | `///` Quality |
|------|-------|---------------|
| `domain/type_descriptor.dart` | 117 | Good - all classes/fields documented |
| `domain/validation.dart` | 132 | Good - 12 doc blocks |
| `domain/repository.dart` | 178 | Good - 4 doc blocks |
| `domain/data_source.dart` | 47 | Good - 4 doc blocks |
| `domain/icon_mapper.dart` | 35 | Good - 5 doc blocks |
| `domain/data_sources/sqlite_data_source.dart` | 150 | Good - 4 doc blocks |
| `domain/data_sources/fallback_data_source.dart` | 134 | Good - 5 doc blocks |
| `core/theme/app_themes.dart` | 217 | Good - 1 doc block covers class |
| `core/theme/settings_panel.dart` | 97 | Good - 2 doc blocks |
| `core/theme/theme_service.dart` | 74 | Good - 2 doc blocks |
| `core/string_resources.dart` | 23 | Good - 4 doc blocks |
| `core/app_config.dart` | 9 | Good - 4 doc blocks |
| `features/layout/breadcrumbs.dart` | 197 | Partially covered, 10 blocks (verify completeness) |

---

## 3. Priority Order

| Priority | Category | Rationale |
|----------|----------|-----------|
| **P1** | `docs/operations/install-guide.md` | Users cannot set up the project without install docs |
| **P2** | `docs/operations/api-reference.md` | Developers cannot use the API surface without reference |
| **P3** | `app_flutter/README.md`, `app_test_harness/README.md` | Currently generic Flutter templates, actively misleading |
| **P4** | Code doc comments on largest undocumented files | Property grid, topology map, layout, tree view model handle core UX |
| **P5** | Code doc comments on remaining undocumented files | Smaller files, view models, entry points |
| **P6** | Root `README.md` - add ToC | Improves discoverability of existing content |
| **P7** | Verify existing operational docs | Path/filename verification pass |

---

## 4. Effort Summary

| Category | Items | Small | Medium | Large |
|----------|-------|-------|--------|-------|
| New operational docs | 2 | 0 | 1 | 1 |
| README rewrites | 2 | 1 | 1 | 0 |
| Code doc comments (zero-coverage) | 12 | 8 | 4 | 0 |
| Code doc comments (partial coverage) | 7 | 6 | 1 | 0 |
| Existing doc path verification | 3+ | 3 | 0 | 0 |
| **Total** | **~26** | **18** | **7** | **1** |

---

## 5. Agent Assignments

| Agent | Scope |
|-------|-------|
| Agent A | Root README ToC, process doc link verification, use-case docs cross-references (3 small items) |
| Agent B | `app_flutter/README.md` rewrite (medium), `app_test_harness/README.md` rewrite (small) |
| Agent C | `install-guide.md` (medium), existing op doc path verification (3 small items) |
| Agent D | `api-reference.md` (large) |
| Agent X | Property grid, topology map, layout, breadcrumbs, database initializer (5 medium) |
| Agent Y | All remaining zero-coverage + partial-coverage code files (8 small + 1 medium) |

---

## 6. Acceptance Criteria

Each doc or file is considered production-quality when:

1. Every public class, enum, mixin, extension, and top-level function has a `///` doc comment
2. Every public field, method, and constructor parameter is documented
3. Doc comments explain *why* not just *what*
4. Operational docs have: prerequisites, step-by-step instructions, expected outputs, troubleshooting section
5. READMEs have: project description, architecture overview, build/run commands, link to docs/
6. All internal file paths and cross-references are verified correct
7. No dead links, no placeholder text ("TODO", "Coming soon"), no generic Flutter template boilerplate
