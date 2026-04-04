# Jac Current Reference

Use this file as a fast current-era Jac guide. It is tuned for helping users code, debug, and navigate the official docs quickly without carrying a full manual in context.

## 0. Docs Lookup
- Primary docs root: `https://docs.jaseci.org/reference/language/`
- Sitemap: `https://docs.jaseci.org/sitemap.xml`
- High-signal pages:
  - Foundation: `https://docs.jaseci.org/reference/language/foundation/`
  - Advanced: `https://docs.jaseci.org/reference/language/advanced/`
  - jac-client: `https://docs.jaseci.org/reference/plugins/jac-client/`
  - byLLM: `https://docs.jaseci.org/reference/plugins/byllm/`
  - jac-scale: `https://docs.jaseci.org/reference/plugins/jac-scale/`
  - CLI: `https://docs.jaseci.org/reference/cli/`
  - Config: `https://docs.jaseci.org/reference/config/`
  - Release notes: `https://docs.jaseci.org/community/release_notes/jaclang/`
- Lookup order:
  1. Local project code and tests
  2. Official page for the relevant subsystem
  3. Sitemap for exact page discovery
  4. Release notes for breaking changes
- If official docs and local runtime disagree, trust the local runtime and project tests over generic reference text.

## 1. Core Syntax
- Jac uses braces `{}` for blocks and semicolons `;` to terminate statements.
- Comments:
  - `# comment`
  - `#* multi-line comment *#`
  - `"""docstring"""`
- Prefer executable module code inside entry blocks rather than bare top-level statements.
- Entry variants:
  - `with entry { }` runs whenever the module loads
  - `with entry:__main__ { }` runs only when the file is executed directly
- Current keywords and special references include `obj`, `node`, `edge`, `walker`, `enum`, `can`, `def`, `match`, `visit`, `spawn`, `report`, `sem`, `by`, `cl`, `sv`, `na`, `async`, `await`, `flow`, `wait`, `lambda`, and `props`.
- Backtick-escaped identifiers exist, but avoid keyword-shaped `has` field names.

## 2. Files and Modules
- File variants:
  - `.jac` = head module
  - `.sv.jac` = server variant
  - `.cl.jac` = client variant
  - `.na.jac` = native variant
  - `.impl.jac` = implementation annex
  - `.test.jac` = test annex
- Files with the same basename form one logical module.
- Packages require `__init__.jac`.
- In package `__init__.jac`, prefer full dotted includes: `include mypackage.nodes;`
- Imports:
  - Plain import: `import math;`
  - Selective import: `import from uuid { uuid4 }`
  - Include merges code into current scope: `include utils;`
- Imports used only in type annotations are automatically optimized into `TYPE_CHECKING`-guarded imports in generated Python.

## 3. Types
- Builtins: `int`, `float`, `str`, `bool`, `bytes`, `list`, `tuple`, `set`, `dict`, `any`, `type`, `None`
- Fixed-width native types for `.na.jac` / C interop: `i8`, `u8`, `i16`, `u16`, `i32`, `u32`, `i64`, `u64`, `f32`, `f64`, `c_void`
- Unions use Python-style syntax: `User | None`
- `Self` is the enclosing archetype in type annotations; `self` is the current instance.
- `True` and `False` are canonical server-side booleans.
- Current docs say generic type parameters are planned; use `any` as a placeholder where needed today.

```jac
obj Example {
    has name: str;
    has count: int = 0;
    has items: list[str] = [];
    has next: Self | None = None;
}
```

## 4. Functions, Methods, and Implementations
- `def` defines functions and methods.
- `can` defines entry/exit abilities for walkers, nodes, and edges.
- `class def` defines class-level methods.
- `impl` separates declarations from implementations and pairs with `.impl.jac`.
- `glob` defines module-level globals.

```jac
glob config: dict = {"debug": True};

def add(x: int, y: int) -> int {
    return x + y;
}

obj Node {
    has value: int = 0;

    class def create(v: int) -> Self {
        return Self(value=v);
    }
}
```

- Lambda forms:
  - Expression: `lambda x: int -> int : x * 2;`
  - Block: `lambda x: int -> int { return x * 2; };`
  - Multi-param: `lambda x: int, y: int -> int : x + y;`
- Keep expression lambdas simple; use block lambdas when assignments or multi-line logic are required.

## 5. Control Flow
- `if` / `elif` / `else`
- `while`
- `for item in items`
- C-style `for i=0 to i<10 by i+=1`
- Prefer `match` / `case` for branching on values
- `switch` is documented, but `match` is clearer and less version-sensitive
- Loop control: `break`, `continue`
- Exceptions: `try`, `except`, `finally`, `raise`
- Assertions: `assert condition;`
- Generators with `yield` are documented

```jac
match value {
    case 1: print("one");
    case 2 | 3: print("two or three");
    case _: print("other");
}
```

## 6. Operators
- Null-safe operators are current official syntax:
  - `user?.name`
  - `config?["key"]`
  - `obj?.method()`
- Walrus operator is supported: `(n := len(items))`
- Boolean operators are Python-style: `and`, `or`, `not`
- Prefer `not x` over JS-style `!x`

## 7. Pipes
- Standard pipes:
  - `|>`
  - `<|`
- Atomic pipes:
  - `:>`
  - `<:`
- Dot pipes:
  - `.>`
  - `<.`

```jac
result = data |> transform |> filter |> output;
start spawn :> DepthFirstWalker();
builder = Builder() .> add(5) .> double();
```

## 8. Archetypes
- `obj` = structured object
- `node` = graph node
- `edge` = graph edge
- `walker` = graph traversal agent
- `enum` = constrained values
- `init` / `postinit` are supported lifecycle hooks
- Inheritance is Python-like:
  - `obj Child(Parent) { }`
  - `walker W(BaseW) { }`

## 9. Object-Spatial Programming
- Untyped connect: `a ++> b;`
- Typed connect: `a +>: Friend() :+> b;`
- Backward typed connect: `a <+: Friend() :<+ b;`
- Disconnect: `a del--> b;`
- Untyped traversal: `[-->]`, `[<--]`
- Typed traversal: `[->:Road:->]`, `[<-:Road:<-]`
- Edge attribute filter: `[->:Road:weight > 5:->]`
- Variable traversal: `[city_a ->:Road:->]`
- Special references: `root`, `here`, `self`, `visitor`
- `Root` is the type used in walker event signatures
- Older backtick-style root type forms are obsolete

```jac
node City { has name: str; }
edge Road { has dist: int = 0; }

walker FindCities {
    has names: list = [];

    can start with Root entry { visit [-->]; }

    can collect with City entry {
        self.names.append(here.name);
        visit [->:Road:->];
    }

    can done with Root exit { report self.names; }
}
```

## 10. Walkers
- Spawn forms:
  - `root spawn W();`
  - `W() spawn root;`
- `visit [-->];` queues next traversal steps
- `visit [-->] else { ... }` handles dead ends
- `report value;` appends to `.reports`
- `skip;` skips remaining code in the current ability
- `disengage;` stops traversal immediately
- Release notes describe current traversal semantics as recursive DFS with deferred exits and LIFO exit order
- Safe access pattern:
  - `result = root spawn W();`
  - `data = result.reports[0] if result.reports else None;`

## 11. Filters, Assign Comprehensions, and Regular Comprehensions
- Standard comprehensions are Python-like:
  - `[x ** 2 for x in range(10)]`
  - `{x: x ** 2 for x in range(5)}`
  - `{len(s) for s in strings}`
  - `(x ** 2 for x in range(1000))`
- Collection filter syntax:
  - `people(?age >= 18)`
  - `employees(?salary > 50000, experience >= 5)`
- Typed filters:
  - `animals(?:Dog)`
  - `animals(?:Cat, indoor == True)`
  - `[-->](?:Person, age > 21)`
- Assign comprehensions:
  - `people(=verified=True);`
  - `people(?age >= 18)(=can_vote=True);`
  - `items(=status="processed", processed_at=now());`

## 12. byLLM / AI Integration
- Core syntax:
  - `def summarize(text: str) -> str by llm();`
  - `def analyze(text: str) -> Sentiment by llm();`
  - `def extract(text: str) -> list[Person] by llm();`
- Configure model globally:

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o");
```

- Project-level config:

```toml
[plugins.byllm]
system_prompt = "You are a concise assistant."
```

- Invocation parameters:
  - `method="Reason"`
  - `method="ReAct"`
  - `tools=[...]`
  - `incl_info={...}`
  - `stream=True`
- Streaming is for `str` outputs; current docs say tool calling is not supported in streaming mode.
- `sem` is first-class current syntax:
  - `sem translate = "Translate while preserving formatting.";`
  - `sem Customer = "CRM customer record";`
  - `sem Customer.id = "UUID";`
  - `sem search_products = "Search catalog records.";`
- Methods using `by llm()` automatically include object attributes as context.
- For tool-heavy agentic functions, keep the tool list small and semantically clear.

## 13. Server vs Client Codespaces
- `sv { }` = server-only block
- `cl { }` = client-only block
- `na { }` = native-only block
- Single-statement forms are current:
  - `cl import from react { useEffect }`
  - `sv import from main { AddTodo }`
  - `cl glob THEME: str = "dark";`

## 14. jac-client / Full-Stack
- Current app entry should be `def:pub app() -> JsxElement`
- Modern jac-client docs require explicit `:pub` exports
- `.cl.jac` files are fully client-side; do not `include` them
- `has` inside client components creates reactive state
- Current official effect forms:
  - `can with entry { ... }`
  - `async can with entry { ... }`
  - `can with exit { ... }`
  - `can with [dep] entry { ... }`
  - `can with (a, b) entry { ... }`
- Manual `useEffect(...)` is also valid if imported from React
- Current docs require immutable updates for reactive list/dict state:
  - RIGHT: `items = items + [x];`
  - WRONG: `items.append(x);`
- Component props are typically `props: dict`; children are `props.children`
- `sv import` lets client code call server walkers and functions
- Two backend-call styles are documented:
  - `await def:pub_function(...)` for exported functions
  - `root spawn Walker(...)` for walkers
- File-based routing is documented and recommended:
  - `pages/index.jac`
  - `pages/users/[id].jac`
  - `pages/layout.jac`
  - route groups like `pages/(auth)/...`
- Routing helpers from `@jac/runtime` include `Router`, `Routes`, `Route`, `Link`, `Navigate`, `useNavigate`, `useParams`, `Outlet`, `AuthGuard`

```jac
cl import from react { useEffect }
sv import from main { ListTodos }

cl {
    def:pub app() -> JsxElement {
        has todos: list = [];

        async can with entry {
            result = root spawn ListTodos();
            todos = result.reports[0] if result.reports else [];
        }

        return <div>{todos.length}</div>;
    }
}
```

## 15. Client-Side JS Interop
- Prefer `className` in JSX-like code; current maintained client repos use `className`
- Use JS-native helpers in client code:
  - `.length` not `len()`
  - `String(x)` not `str(x)`
  - `parseInt(x)` not `int(x)`
  - `Math.min` / `Math.max`
  - `.trim()` not `.strip()`
- `None` becomes `null` in client context
- `new` is not used directly in current docs; use `Reflect.construct(...)`
- Client env vars exposed through Vite use the `VITE_` prefix
- Current maintained `.cl.jac` repos also use lowercase `true` / `false` in places; treat client-side boolean literal style as runtime-sensitive and match the project you are editing.

## 16. Functions vs Walkers
- `def:pub` is the simple endpoint pattern for shared or straightforward request/response logic
- `walker` is the right tool for traversal, accumulators, and graph-native workflows
- Tutorials currently recommend `walker:priv` for authenticated per-user graph flows
- Modern jac-scale docs also describe walker access levels separately; verify exact runtime semantics when choosing `:priv`

## 17. jac-scale / Server APIs
- `jac start app.jac` starts the local API server
- By default, each walker becomes an endpoint at `POST /walker/<WalkerName>`
- Walker `has` fields become request body parameters
- Current docs say walker `report` values become the HTTP response
- Middleware walkers are current documented syntax:
  - `_before_request`
  - `_authenticate`
- Middleware walkers can receive `request: dict` or `headers: dict`
- For standard auth, prefer built-in endpoints:
  - `POST /user/register`
  - `POST /user/login`
- `@restspec` customizes method, path, or protocol

```jac
import from http { HTTPMethod }

@restspec(method=HTTPMethod.GET, path="/custom/users")
walker :pub list_users {
    can fetch with Root entry { report []; }
}

@restspec(protocol=APIProtocol.WEBSOCKET)
async walker :pub EchoMessage {
    has message: str;
    async can echo with Root entry { report {"echo": self.message}; }
}
```

- Current jac-scale docs:
  - `@restspec(protocol=APIProtocol.WEBHOOK)` exposes `/webhook/<WalkerName>`
  - `@restspec(protocol=APIProtocol.WEBSOCKET)` exposes `/ws/<WalkerName>`
  - Swagger UI is at `/docs`
  - OpenAPI JSON is at `/openapi.json`
- `APIProtocol` is a builtin enum in current release notes

## 18. Access Control and Permissions
- Current jac-scale access constants:
  - `NO_ACCESS`
  - `READ`
  - `CONNECT`
  - `WRITE`
- Current permission helpers:
  - `perm_grant(node, READ);`
  - `perm_revoke(node);`
  - `allow_root(node, target_root_id, WRITE);`
  - `disallow_root(node, target_root_id, READ);`
- `:pub` = public endpoint
- Default walker access = protected / JWT-authenticated
- `:priv` behavior is documented inconsistently across current docs and tutorials; confirm with local runtime before depending on it for external API behavior

## 19. Storage and Persistence
- Nodes attached to roots persist in graph storage
- `commit();` persists current memory state in jac-scale
- Current scale docs add `store()` for file/blob storage

```jac
glob storage = store(base_path="./uploads", create_dirs=True);
```

```toml
[storage]
storage_type = "local"
base_path = "./storage"
create_dirs = true
```

## 20. Native Compilation
- `.na.jac` is native-variant Jac
- C interop uses direct library imports such as:

```jac
import from "libm" {
    def sin(x: f64) -> f64;
    def cos(x: f64) -> f64;
    def sqrt(x: f64) -> f64;
}
```

- Compile standalone native executables with `jac nacompile`

## 21. Testing
- Current advanced docs show named test blocks:

```jac
test addition_works {
    assert add(2, 3) == 5;
}
```

- Current docs also show:
  - `jac test`
  - `jac test --test-name test_addition`
  - `jac test --verbose`
- `JacTestClient` is documented for API tests without starting a server:

```jac
import from jaclang.testing { JacTestClient }
```

- Older 0.10.x guides may say test names are removed. Verify against the actual runtime in the project you are editing.

## 22. CLI
- Core:
  - `jac file.jac` = shorthand for `jac run file.jac`
  - `jac run`
  - `jac start`
  - `jac check`
  - `jac test`
  - `jac format`
  - `jac lint`
  - `jac debug`
  - `jac dot`
  - `jac enter`
- Project/deps:
  - `jac create`
  - `jac add`
  - `jac install`
  - `jac remove`
  - `jac update`
- Client/build:
  - `jac create myapp --use client`
  - `jac build`
  - `jac setup`
- Maintenance:
  - `jac clean`
  - `jac purge`
  - `jac grammar`
  - `jac tool`
  - `jac lsp`

## 23. Configuration
- `jac.toml` is the central config file
- High-value sections:
  - `[project]`
  - `[dependencies]`
  - `[dev-dependencies]`
  - `[dependencies.npm]`
  - `[dependencies.npm.dev]`
  - `[run]`
  - `[serve]`
  - `[build]`
  - `[test]`
  - `[check]`
  - `[check.lint]`
  - `[storage]`
  - `[plugins]`
  - `[plugins.byllm]`
  - `[plugins.scale.*]`
  - `[plugins.client.*]`
  - `[scripts]`
  - `[environment]`
  - `[environments.<name>]`
- Current docs support:
  - profile activation with `--profile` or `JAC_PROFILE`
  - profile override files such as `jac.prod.toml`
  - local developer overrides in `jac.local.toml`
  - `.jacignore`
- Important full-stack settings:
  - `[serve] base_route_app = "app"`
  - `[serve] cl_route_prefix = "cl"`

## 24. High-Value Gotchas
- `Root` is the event-signature type; older backtick-type forms are obsolete
- Old filter syntax like `(?Type:field==val)` was replaced; use `(?:Type, field == val)`
- Use `with entry {}` or `with entry:__main__ {}` instead of relying on bare top-level runtime code
- Use immutable state updates in `cl {}`; do not mutate reactive lists in place
- Prefer `className` in JSX-like code even if some older tutorials still show `class`
- Distinguish client-call styles:
  - exported functions return direct values
  - walker spawns return objects with `.reports`
- Modern jac-client requires explicit `:pub` exports; older versions auto-exported defs
- Testing syntax and CLI flags differ across versions; current docs show named tests

## 25. Repo Drift
- Maintained client repos such as `jac-client-playground` and `littleX` confirm:
  - `can with entry` and dependency effects like `can with [isLoggedIn] entry`
  - `className`
  - `sv import`
  - `root spawn ...` inside client code
  - `.impl.jac` split implementations
- Public example repos such as `jac_playground` still contain older object-spatial syntax, including:
  - old typed filters like ``(`?Person)``
  - older connect formatting like `a +>:Edge:+> b`
- Some maintained repos still use `-> Any` for client components instead of the newer `-> JsxElement` guidance in the docs.
- Do not treat public examples as canonical without checking current docs and release notes.

## 26. Version Drift and Compatibility
- Current docs are broader than older 0.10.x cheat sheets. Main differences:
  - named tests are back in current docs
  - client effects are documented via `can with entry` / `can with exit` / dependency forms
  - client state updates are immutable, not `append()`-based
  - `@restspec` and `APIProtocol` are current jac-scale patterns
  - permission helpers now center on `perm_grant` / `allow_root` rather than older `__jac__` object helpers
- Some current docs still conflict with each other, especially around `walker:priv`. Treat `:priv` as version-sensitive and runtime-sensitive.
- When editing an existing codebase, match the runtime and surrounding code style before applying "current docs" changes mechanically.
