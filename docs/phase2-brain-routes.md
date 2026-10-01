# Phase 2 notes: the member and client routes, as the brain's code has them

_Read on 2026-10-01 from mantle branch `feat/mobile-roles` (not merged; shapes
may move with its review). A research note for the three-role work, not a
contract: the contract is mantle `docs/mobile-companion-backend.md`. Delete
this file once the Dart models and their fixtures exist._

**The finding that shapes the work:** a member or a client cannot export a
page as markdown (`GET /api/export/:id` answers them 401), and their page
routes carry a ProseMirror document. The phone renders pages from markdown
today. So either the brain adds a markdown read for these roles, or the phone
gains a ProseMirror renderer. Ask the brain session before building either.

I've covered all nine of your items below, and quoted the types verbatim. The main things for the Dart client:

- **The shell carries no feature flags.** Nothing in it says whether chat is on. You only learn that when `GET .../chat` answers `agent: null`.
- **Error bodies differ between member and client chat.** Several member chat refusals have no `reason` field, while the client ones do (see item 2).
- **Several wire bodies carry more fields than the TypeScript contract declares.** Build your Dart models to ignore unknown keys.

Everything is on `feat/mobile-roles`. "Code" below means the route handlers and the content layer, which I trusted wherever they disagreed with the docs.

**General wire facts that apply to every route below**
- **Missing or invalid bearer:** every `/api/**` request without a valid credential gets `401 {"error":"unauthorized"}` with `Cache-Control: no-store`. This comes from the gate at `server/web/server/middleware/gate.ts:140-145,228,269`.
- **Bad bearer plus `?at=`:** if you send a bearer that is badly signed or the wrong kind, the gate answers 401 straight away, even when a valid `?at=` is also present (`gate.ts:221-229`). On byte requests, send either a working bearer or `?at=`, never a stale bearer.
- **Revoked bearer:** a bearer that is signed correctly but revoked or expired gets past the gate. The handler then answers 401, or a byte route falls back to `?at=`.
- **Wrong role:** these 403 answers come from `server/web/lib/auth/session.ts:569-584` and `:638-661`.

| Caller → route | Status | Body |
|---|---|---|
| member → admin route (`getOwnerOr401`) | 403 | `{"error":"forbidden","reason":"member-login","message":"Not available to member logins."}` |
| client → admin route | 403 | `{"error":"forbidden","reason":"client-login","message":"Not available to client logins."}` |
| client → member route | 403 | `{"error":"forbidden","reason":"client-login","message":"Not available to client logins."}` |
| admin → member route | 403 | `{"error":"forbidden","reason":"admin-login","message":"This route is for member logins."}` |
| admin → client route | 403 | `{"error":"forbidden","reason":"admin-login","message":"This route is for client logins."}` |
| member → client route | 403 | `{"error":"forbidden","reason":"member-login","message":"This route is for client logins."}` |
| member/client → admin **byte** routes (`getOwnerForAsset`: `/api/files/files/*`, `/api/draws/:id/svg`, `/api/export/:id`, …) | **401** | `{"error":"unauthorized"}`, not 403 (`session.ts:167-204`) |

- **Allow-lists:** `MEMBER_ROUTES` and `CLIENT_ROUTES` are only checked by the sweep tests. Nothing reads them at runtime. Each handler's own gate does the enforcing.
- **Personal-space state errors** (`server/web/lib/member-space.ts:46-64`) have this body: `{ error: string, reason, ids?: string[] }`.
  - Status by `reason`: `not-found` → 404, `invalid` → 400, `comment-cap` → 429, everything else → 409.
  - The reasons are `not-found | frozen | not-draft | not-submitted | unsaved-draft | quota | embed | not-shared | too-large | invalid | with-admin | author-inactive | taken | comment-cap | thread-full` (`packages/content/src/member-space-core.ts:16-42`).
- **Write rate limit:** 429 `{"error":"Too many changes at once. Wait a moment, then try again.","reason":"rate-limit"}` with a `retry-after` header. The limit is 120 writes a minute per login, for both members and clients.
- **Byte rate limit:** 429 `{"error":"Too many requests. Try again shortly.","reason":"rate-limit"}`. The limit is 240 a minute, and 60 a minute with `?thumb=1`.

---

### 1. Shell

**GET /api/member/shell** (no query). Handler: `server/web/app/api/member/shell/route.ts:19-58`. Type: `packages/client-types/src/dto/member.ts:12-38`.
```ts
export type MemberShell = {
  role: 'member';
  loginId: string;
  displayName: string | null;
  email: string;
  avatar: { style: string; seed: string; parts: unknown } | null;
  avatarPhotoVersion: string | null;
  /** Append as `?at=` to /api/member/files/* and /api/member/draws/* srcs. */
  assetToken: string;
  siteName: string | null;
  colorTheme: string | null;
  fontLogo: string | null;
  fontTitle: string | null;
  fontUi: string | null;
  fontProse: string | null;
  fontSize: string | null;
  fontLogoSize: string | null;
  fontTitleSize: string | null;
  fontProseSize: string | null;
  logoVersion: string | null;
  logoDarkVersion: string | null;
  treeKinds?: TreeKind[];
};
```

**GET /api/client/shell**. Handler: `server/web/app/api/client/shell/route.ts:20-56`. Type: `packages/client-types/src/dto/client.ts:13-37`.
```ts
export type ClientShell = {
  role: 'client';
  loginId: string;
  displayName: string | null;
  email: string;
  /** Append as `?at=` to /api/client/files/* and /api/client/draws/* srcs. */
  assetToken: string;
  siteName: string | null;
  colorTheme: string | null;
  fontLogo: string | null;
  fontTitle: string | null;
  fontUi: string | null;
  fontProse: string | null;
  fontSize: string | null;
  fontLogoSize: string | null;
  fontTitleSize: string | null;
  fontProseSize: string | null;
  logoVersion: string | null;
  logoDarkVersion: string | null;
  treeKinds?: TreeKind[];
};
```

- **Asset token lifetime:** 2 h for a member and 10 min for a client (`server/web/lib/auth/tokens.ts:276,281`). It also dies as soon as the login's session epoch changes (sign-out, End sessions, disable). The shell gives no expiry field, so call the shell again for a fresh token.
- **`treeKinds`** is always sent now, as `[...READER_TREE_KINDS]` (`packages/content/src/tree/kinds.ts:43-45`). That is the live kinds whose node type is a member kind, which should be files, notes, pages, draw and tables.
- **What the shell does not carry:** any chat/responder flag, nav flags, notices or banners, or a role-features list.
  - Chat is open only when `GET .../chat` answers a non-null `agent`.
  - The brand name is `siteName`. The client app also shows it as the author of reviewer comments, falling back to `"Reviewer"` (`server/web/lib/client-space.ts:128-141`).
- **Non-200:** 401, or 403 for the wrong role. The preference reads never fail the shell: a failed read just comes back as unset fields.

### 2. Chat

**GET /api/member/chat?before=ISO** (`server/web/app/api/member/chat/route.ts:90-125`)
- Paging: always 50 messages. `before` is exclusive, and a value that is not a valid date is silently ignored.
- Order: you get the newest 50 before the cursor, sorted **ascending** within the page (`packages/content/src/team-messages.ts:130-157`). For the next page, set `before` to the oldest message's `createdAt`.
- Types: `member.ts:78-91`.
```ts
export type MemberChatMessage = {
  id: string;
  direction: 'inbound' | 'outbound';
  text: string;
  status: 'pending' | 'complete' | 'failed';
  failed: boolean;
  createdAt: string;
};
/** GET /api/member/chat. `agent` null = chat not open yet (no team-level agent). */
export type MemberChatThread = {
  agent: { slug: string; name: string } | null;
  messages: MemberChatMessage[];
};
```
- **Direction:** `inbound` is the person, `outbound` is the agent.
- **No author field and no attachments.** "Not yet: attachments in chat" (`docs/member-logins.md:228`).
- **`text` is markdown.** Images in it are rewritten to relative `/api/member/files/<id>` or `/api/member/draws/<id>/svg`, and images the reader may not see are removed (`packages/content/src/chat-images.ts:43-46,160-171`). Load them with your bearer, or append `?at=`.
- **Pending reply:** the turn engine first writes the inbound row, then an empty outbound row with `status:'pending'`, then fills it in as `complete` or `failed` (`packages/runtime/src/assistant/run-team-turn.ts:387-422`).
  - Poll GET while any row is `pending`.
  - The inbound row is written by the queued workflow, so it may not exist yet right after the 202. Show the sent message optimistically.

**POST /api/member/chat** (`route.ts:127-240`)
- Body: `{ text: string }`. Text is trimmed, at least 1 character, at most `ASSISTANT_TURN_MAX_CHARS = 20_000` (`packages/client-types/src/assistant-limits.ts:17`). NUL characters are stripped.
- Optional header `Idempotency-Key`, cut to 64 characters. The same key with the same text is the same turn and gets 202 again.
- 202 answer: `{ turnId: string }` (the turn id has the form `member-<loginId>.<key|uuid>`).
- No upload support of any kind.

| Status | Body | When |
|---|---|---|
| 409 | `{"error":"Chat is not open yet: the admin has not set a team-level agent."}` | Responder is off. **No `reason`.** |
| 429 | `{"error":"too many messages - give me a moment"}` + `Retry-After` | More than 6 a minute. **No `reason`.** |
| 400 | `{"error":"<first zod issue>"}` | e.g. `"type a message first"` or `"message too long: …"` |
| 429 | `{"error":"daily message limit reached (100/day). Try again tomorrow.","reason":"daily_cap"}` | Daily turn cap |
| 429 | `{"error":"daily usage limit reached for the chat. …","reason":"token_budget"}` | Daily token budget |
| 409 | `{"error":"that Idempotency-Key was already used for a different message","reason":"idempotency-key-reused"}` | Same key, different text |
| 500 | `{"error":"something went wrong handling that message - the brain admin can see the details"}` | Server failure |

The daily caps default to `TEAM_CHAT_DAILY_TURNS` = 100 turns and `MANTLE_MEMBER_DAILY_TOKENS` = 2,000,000 tokens (`server/web/lib/member-daily-cap.ts:15-28`).

**GET/POST /api/client/chat** (`server/web/app/api/client/chat/route.ts:90-241`) works the same way, with these differences:
- Types: `client.ts:237-267`.
```ts
export type ClientChatMessage = {
  id: string;
  direction: 'inbound' | 'outbound';
  text: string;
  status: 'pending' | 'complete' | 'failed';
  failed: boolean;
  createdAt: string;
};
export type ClientChatThread = {
  agent: { name: string } | null;
  messages: ClientChatMessage[];
};
export type ClientChatQueued = { turnId: string };
export type ClientChatRefusedReason =
  'chat-closed' | 'idempotency-key-reused' | 'rate-limited' | 'daily_cap' | 'token_budget';
```
- **Refusals carry a `reason`:**
  - 409 `{"error":"Chat is not open yet.","reason":"chat-closed"}`
  - 429 `{"error":"too many messages, give me a moment","reason":"rate-limited"}` with `Retry-After`
- **Agent:** `agent` has no `slug`. It is `client-responder`, and only while it is exactly at client level.
- **Queueing:** one turn in flight per client. A queued turn dies if the session epoch changes.
- **Pictures:** rewritten to `/api/client/files/<id>` and `/api/client/draws/<id>/svg`.

There is **no DELETE, stop, cancel or upload route** for either chat. None is in either allow-list.

### 3. Member "my items", Library, accepted

**GET /api/member/items?kind=&q=&state=&page=** is the one combined list (`server/web/app/api/member/items/route.ts:30-145`).
- Query values:
  - `kind`: `page|note|draw|table|file`.
  - `q`: at most 200 characters, matched against the title.
  - `state`: `all|private|draft|submitted|returned|with-admin|brain|by-me|client-requests` (`packages/client-types/src/member-kinds.ts:19-30`).
  - `page`: 1 to 100.
- Page size is 50, newest `updatedAt` first.
- An invalid query gets 400 `{"error":"Invalid query."}`.
- Types: `member.ts:285-332`.
```ts
export type MemberItemSource = 'own' | 'team' | 'library' | 'accepted' | 'client-request';
export type MemberItemPill = 'private' | 'draft' | 'submitted' | 'returned' | 'with-admin';
export type MemberItemRow = {
  id: string;
  type: MemberItemKind;
  title: string;
  icon: string | null;
  summary: string | null;
  updatedAt: string;
  source: MemberItemSource;
  pill: MemberItemPill | null;
  audience: AccessLevel | null;
  author: MemberItemAuthor | null;
  byMe: boolean;
  space: MemberSpaceItemRow | null;
};
export type MemberItemsPage = { items: MemberItemRow[]; total: number; page: number; pageSize: number };
```
- Supporting types (`member.ts:99-121`, `dto/access.ts:12-13,41-45`):
```ts
export type MemberReviewState = 'draft' | 'submitted' | 'returned' | 'accepted' | 'taken';
export type MemberSpaceItemState = MemberReviewState | 'with-admin';
export type MemberSpaceItemRow = {
  id: string;
  type: MemberItemKind;
  title: string;
  icon: string | null;
  sharing: MemberSpaceSharing;            // 'private' | 'team'
  reviewState: MemberSpaceItemState;
  submittedAt: string | null;
  returnedNote: string | null;
  authorLoginId: string | null;
  createdAt?: string;
  updatedAt: string;
};
export type AccessLevel = 'admin' | 'team' | 'client' | 'public';
export type MemberItemAuthor = { name: string; acceptedAt: string | null; role?: 'member' | 'client' | null };
```
- **How pills are assigned** (`packages/content/src/member-items.ts:32-48`):

| Row | Pill |
|---|---|
| `taken` or `with-admin` | `with-admin` |
| `submitted` | `submitted` |
| `returned` | `returned` |
| `accepted` | none |
| `draft` shared with the team | `draft` |
| `draft` kept private | `private` |

- **Which route opens each source:**

| `source` | Open with |
|---|---|
| `own` | `GET /api/member/space/:id` |
| `team` | `GET /api/member/team-drafts/:id` |
| `library` | `GET /api/member/library/:id` |
| `accepted` | `GET /api/member/accepted/:id` |
| `client-request` | `GET /api/member/client-requests/:id` |

- **Accepted items at team or client level** come back with `source:'library'` and `byMe:true` (`member-items.ts:170-191`).

**Older single-source lists** are still served:
- **`GET /api/member/space?kind=&q=&review=&page=`** returns `MemberSpaceList` (`member.ts:129-134`): `{items: MemberSpaceItemRow[], total, page, pageSize}`.
  - `review` is a comma list of states plus `with-admin`. An unknown state gets 400.
  - Page 1 starts with the `with-admin` rows (title and kind only).
- **`GET /api/member/team-drafts`** and **`GET /api/member/client-requests`**. The second one returns `MemberItemsPage` rows.

**GET /api/member/space/:id?tab=** (`server/web/app/api/member/space/[id]/route.ts:37-51`)
- 200 is `MemberSpaceItem` (`member.ts:203-228`).
```ts
export type MemberSpaceItemBody<TDoc = unknown, TTable = unknown> =
  | { type: 'page'; page: { doc: TDoc; draft: TDoc | null; draftRev?: number; title: string; folderId?: string | null } }
  | { type: 'note'; note: { content: string; title: string } }
  | { type: 'draw'; draw: { scene: TDoc; draft: TDoc | null; draftRev?: number } | null }
  | { type: 'table'; table: TTable }
  | { type: 'file'; file: MemberSpaceFile };
export type MemberSpaceItem<TDoc = unknown, TTable = unknown> = { row: MemberSpaceItemRow; body: MemberSpaceItemBody<TDoc, TTable> };
```
- **The wire body has more fields than this type.** The page body is the full `PageDetail` (`packages/content/src/pages/shared.ts:21-42`). The note body is the full `NoteRow` (`packages/content/src/notes.ts:26-43`), with `id, tags, summary, audience, inherited, embedded, createdAt, updatedAt`. The table body is `TableDetail` (`packages/content-core/src/table-model.ts:842-889`).
- **Errors:**
  - Bad id → 400 `{"error":"Invalid id."}`.
  - Unknown or someone else's item → 404 `{"error":"Not found."}`.
  - Item an admin took over → 409 `{"error":"An admin is working on this item. It comes back to you if they give it back; if they accept it, it shows under Accepted.","reason":"with-admin"}` (`packages/content/src/member-space.ts:348-353`).

**GET /api/member/library?kind=&q=&page=** and **/library/:id?tab=** (`server/web/app/api/member/library/route.ts`, `[id]/route.ts`). Types: `member.ts:42-76`.
```ts
export type MemberLibraryRow = { id: string; type: MemberLibraryKind; title: string; icon: string | null;
  summary: string | null; audience: 'team' | 'client'; updatedAt: string; author?: MemberItemAuthor | null };
export type MemberLibraryPage = { items: MemberLibraryRow[]; total: number; page: number; pageSize: number };
export type MemberLibraryItem =
  | (MemberLibraryRow & { type: 'page'; doc: unknown; folderId?: string | null })
  | (MemberLibraryRow & { type: 'note'; content: string })
  | (MemberLibraryRow & { type: 'table'; table: unknown })
  | (MemberLibraryRow & { type: 'draw' })
  | (MemberLibraryRow & { type: 'file'; filename: string; mimeType: string | null; sizeBytes: number | null });
```
- `/library/:id` returns `{ item }`. An item above team level gets 404.
- `table` is the full `TableDetail` (`packages/content/src/member-library.ts:180-190`).
- Public items are left out of the list but can still be opened by id, and they show `audience:'team'`.

**GET /api/member/accepted?kind=&q=&page=** and **/accepted/:id?tab=** return `{ item }`. Types: `member.ts:233-274`.
```ts
export type MemberAcceptedRow = { id: string; type: MemberItemKind; title: string; icon: string | null;
  audience: AccessLevel; inherited?: 'team' | 'client' | null; acceptedAt: string | null; updatedAt: string };
export type MemberAcceptedPage = { items: MemberAcceptedRow[]; total: number; page: number; pageSize: number };
export type MemberAcceptedItem =
  | (MemberAcceptedRow & { type: 'page'; doc: unknown; folderId?: string | null })
  | (MemberAcceptedRow & { type: 'note'; content: string })
  | (MemberAcceptedRow & { type: 'table'; table: unknown })
  | (MemberAcceptedRow & { type: 'draw'; changedByAdmin?: boolean })
  | (MemberAcceptedRow & { type: 'file'; filename: string; mimeType: string | null; sizeBytes: number | null; changedByAdmin?: boolean });
```
- This is the version as it was accepted (a snapshot), with the page or note redacted at team level.
- Anything that is not yours or not accepted gets 404.

**Markdown or ProseMirror?**
- **Pages** (the `doc` and `draft` fields) are ProseMirror/TipTap JSON (`Record<string, unknown>`).
- **Notes** (`content`) are markdown.
- **Chat `text`** is markdown.
- **Comment `body`** is a plain string.
- **No markdown export exists for either role.** `GET /api/export/:id` uses `getOwnerForAsset` (`server/web/app/api/export/[id]/route.ts:33`), so a member or client gets **401 `{"error":"unauthorized"}`**. Nothing in either allow-list exports.

### 4. Client: shared items, own items, comments

**GET /api/client/shared?kind=&q=&page=** and **/shared/:id?tab=** return `{ item }`. Handlers: `server/web/app/api/client/shared/*`. Types: `client.ts:39-109`.
```ts
export type ClientSharedRow = { id: string; type: MemberItemKind; title: string; icon: string | null;
  summary?: string | null; updatedAt: string };   // summary never sent since 0.232.333
export type ClientSharedPage = { items: ClientSharedRow[]; total: number; page: number; pageSize: number };
export type ClientSharedItem =
  | (ClientSharedRow & { type: 'page'; doc: unknown; folderId?: string | null })
  | (ClientSharedRow & { type: 'note'; content: string })
  | (ClientSharedRow & { type: 'table'; table: ClientSharedTable })
  | (ClientSharedRow & { type: 'draw' })
  | (ClientSharedRow & { type: 'file'; filename: string; mimeType: string | null; sizeBytes: number | null });
export type ClientSharedTableColumn = { id: string; name: string; type: string };
export type ClientSharedTableRow = { id: string; cells: Record<string, string | number | boolean | string[] | null> };
export type ClientSharedTable = {
  data: { columns: ClientSharedTableColumn[]; rows: ClientSharedTableRow[]; aggregates?: Record<string, string> };
  docClipped?: boolean;
  tabs?: { id: string; name: string; rows: number; columns: number }[];
  tabId?: string | null;
  rowCount?: number;
};
export const CLIENT_PRIVATE_LABEL = 'Private item';
```
- Pages and notes are redacted: a link or mention the client cannot read reads "Private item" and points nowhere, and such embeds are dropped (`packages/content/src/client-shared.ts:133-171`).
- Errors: 400 `Invalid id.` or `Invalid tab.`, and 404 `Not found.`

**The client's own items ("My requests")**
- **List:** `GET /api/client/items?kind=page|note|file&q=&state=all|private|submitted|returned|with-admin|accepted&page=`. Handler: `server/web/app/api/client/items/route.ts`. Types: `client.ts:284-310`.
```ts
export type ClientItemSource = 'own' | 'accepted';
export type ClientItemRow = { id: string; type: ClientItemKind; title: string; icon: string | null; updatedAt: string;
  source: ClientItemSource; pill: MemberItemPill | null; space: MemberSpaceItemRow | null; acceptedAt: string | null };
export type ClientItemsPage = { items: ClientItemRow[]; total: number; page: number; pageSize: number };
```
- **Open an own item:** `GET /api/client/space/:id` returns the same `{row, body}` shape as a member's, for page, note and file only. Any other kind gets 404.
  - A reviewer took it over → 409 `{"error":"A reviewer is working on this item. It comes back to you if they return it; if they accept it, it shows under Accepted.","reason":"with-admin"}` (`server/web/lib/client-space.ts:55-70`).
- **Open an accepted item:** `GET /api/client/accepted/:id` returns `{ item }` (`client.ts:344-361`).
```ts
export type ClientAcceptedItem =
  | (ClientAcceptedBase & { type: 'page'; doc: unknown; folderId?: string | null })
  | (ClientAcceptedBase & { type: 'note'; content: string })
  | (ClientAcceptedBase & { type: 'file'; filename: string; mimeType: string | null; sizeBytes: number | null; changedByAdmin?: boolean });
export type ClientAcceptedBase = { id: string; title: string; icon: string | null; acceptedAt: string | null; updatedAt: string };
```
- **States:** `submitted` freezes the item. Recall turns it back into a draft. `returned` carries `space.returnedNote`. A client can never share with the team, so the pill is never `draft`.

**Comments.** Every thread uses the same shape (`client.ts:376-387`, `dto/rows.ts:53,61-70`).
```ts
export type ClientCommentThread = { comments: NodeComment[]; hasMore?: boolean };
export type NodeCommentAuthorKind = 'owner' | 'member' | 'agent' | 'client';
export type NodeComment = { id: string; nodeId: string; authorKind: NodeCommentAuthorKind; authorName: string;
  mine: boolean; body: string; createdAt: string; editedAt: string | null };
```
- **Paging:** each read answers the newest 100, oldest first. Pass `?before=<ISO>` for the page before; a value that is not an ISO time gets 400 `` {"error":"`before` must be an ISO time."} ``.
- **Writing:** POST `{body}` (at most 10,000 characters) returns 201 `{ comment }`. DELETE `/comments/:commentId` returns `{ok:true}`, or 404.
- **Client thread on a shared item:** `/api/client/shared/:id/comments`.
  - Only client-level items have one; anything else gets 404.
  - The body is trimmed and must be at least 1 character.
  - Limits: 20 writes a minute (429 `rate-limit`), 100 a day (429 `comment-cap`), 1000 per thread (409 `thread-full`).
- **Review talk on the client's own item:** `/api/client/space/:id/comments`.
  - You can only post while the item is submitted; otherwise 409 `not-shared`.
  - Reviewers' comments show `authorName` set to the brand name.
- **Member equivalents:**
  - `/api/member/library/:id/comments` (client-level items only, otherwise 404).
  - `/api/member/space/:id/comments` (only while the item is shared or submitted, otherwise 409 `not-shared`).
  - `/api/member/team-drafts/:id/comments`.

### 5. Files and images

**Which routes serve bytes, and how they authenticate**
- **Member:** `/api/member/files/:id`, `/api/member/draws/:id/svg`, `/api/member/space/:id/bytes`, `/api/member/team-drafts/:id/bytes`, `/api/member/client-requests/:id/bytes`.
- **Client:** `/api/client/files/:id`, `/api/client/draws/:id/svg`, `/api/client/space/:id/bytes`.
- **Auth:** each route accepts a session, a bearer, or `?at=`. The routes call `getMemberForAsset` or `getClientForAsset`, which try the session or bearer first (`session.ts:229-244,609-624`). The gate lets `?at=` through on exactly these GET paths (`gate.ts:35-79`).
- **`?at=` checks:** the token must be kind `a` and carry `act`, which must be a usable login of the right role, on the current epoch and the same brain. A member token is refused on client routes, and the other way round.

**File and thumbnail responses**
- **`?thumb=1`** returns a JPEG thumbnail with `etag` `"<sha>.thumb"`. It answers 304 to a matching `If-None-Match`, or 404 `{"error":"no thumbnail"}`.
- **Full file:** streamed with `content-length`. Images, PDF, text, audio and video are served `inline`; everything else is an `attachment` labelled `application/octet-stream` (`packages/client-types/src/lib/safe-download.ts`).
- **File route errors:** 404 `{"error":"not found"}` (lowercase) and 400 `{"error":"invalid id"}`.

**Drawing SVG responses**
- `image/svg+xml` with `cache-control: private, max-age=300`.
- Errors are **plain text**, not JSON: 404 `Not found` and 400 `Invalid id`.

**Metadata routes (there is no HEAD route)**
- Brain file: `GET /api/{member/library|client/shared}/:id` (file variant) gives `filename`, `mimeType`, `sizeBytes`.
- Own, team-draft or client-request file: `body.file` is `MemberSpaceFile` (`member.ts:189-196`).
```ts
export type MemberSpaceFile = { id: string; filename: string; extension: string; mimeType: string; sizeBytes: number; sha256: string | null };
```

### 6. The allow-lists, every pattern

**`MEMBER_ROUTES`** (`server/web/lib/auth/member-routes.ts:12-96`):
`GET /api/member/shell`, `GET /api/member/library`, `GET /api/member/library/:id`, `GET /api/member/tree/:kind`, `GET /api/member/tree/:kind/search`, `POST /api/member/tree/:kind/folders`, `PATCH /api/member/tree/:kind/folders/:id`, `DELETE /api/member/tree/:kind/folders/:id`, `POST /api/member/tree/:kind/move`, `GET /api/member/files/:id`, `GET /api/member/draws/:id/svg`, `GET /api/member/chat`, `POST /api/member/chat`, `GET /api/member/chat/unread`, `POST /api/member/chat/read`, `POST /api/member/push/connect`, `POST /api/member/push/subscriptions`, `GET /api/member/push/subscriptions`, `DELETE /api/member/push/subscriptions/:id`, `GET /api/member/push/preferences`, `PUT /api/member/push/preferences`, `GET /api/member/space`, `POST /api/member/space`, `GET /api/member/space/:id`, `PATCH /api/member/space/:id`, `DELETE /api/member/space/:id`, `PUT /api/member/space/:id/draft`, `POST /api/member/space/:id/save`, `POST /api/member/space/:id/share`, `POST /api/member/space/:id/submit`, `POST /api/member/space/:id/recall`, `POST /api/member/space-files`, `GET /api/member/space/:id/bytes`, `GET /api/member/space/:id/comments`, `POST /api/member/space/:id/comments`, `DELETE /api/member/space/:id/comments/:commentId`, `GET /api/member/team-drafts/:id/comments`, `POST /api/member/team-drafts/:id/comments`, `DELETE /api/member/team-drafts/:id/comments/:commentId`, `GET /api/member/realtime`, `GET /api/member/team-drafts`, `GET /api/member/team-drafts/:id`, `GET /api/member/team-drafts/:id/bytes`, `GET /api/member/apps`, `POST /api/member/apps/:id/frame-ticket`, `GET /api/member/apps/:id/frame`, `POST /api/member/apps/:id/tool-broker`, `POST /api/member/apps/:id/db-broker`, `GET /api/member/home`, `GET /api/member/accepted`, `GET /api/member/accepted/:id`, `GET /api/member/items`, `GET /api/member/client-requests`, `GET /api/member/client-requests/:id`, `GET /api/member/client-requests/:id/bytes`, `GET /api/member/library/:id/comments`, `POST /api/member/library/:id/comments`, `DELETE /api/member/library/:id/comments/:commentId`.

**`CLIENT_ROUTES`** (`server/web/lib/auth/client-routes.ts:13-74`):
`GET /api/client/shell`, `GET /api/client/shared`, `GET /api/client/shared/:id`, `GET /api/client/tree/:kind`, `GET /api/client/tree/:kind/search`, `GET /api/client/shared/:id/comments`, `POST /api/client/shared/:id/comments`, `DELETE /api/client/shared/:id/comments/:commentId`, `GET /api/client/files/:id`, `GET /api/client/draws/:id/svg`, `GET /api/client/chat`, `POST /api/client/chat`, `GET /api/client/chat/unread`, `POST /api/client/chat/read`, `POST /api/client/push/connect`, `POST /api/client/push/subscriptions`, `GET /api/client/push/subscriptions`, `DELETE /api/client/push/subscriptions/:id`, `GET /api/client/push/preferences`, `PUT /api/client/push/preferences`, `GET /api/client/space`, `POST /api/client/space`, `GET /api/client/space/:id`, `PATCH /api/client/space/:id`, `DELETE /api/client/space/:id`, `PUT /api/client/space/:id/draft`, `POST /api/client/space/:id/save`, `POST /api/client/space/:id/submit`, `POST /api/client/space/:id/recall`, `POST /api/client/space-files`, `GET /api/client/space/:id/bytes`, `GET /api/client/space/:id/comments`, `POST /api/client/space/:id/comments`, `DELETE /api/client/space/:id/comments/:commentId`, `GET /api/client/items`, `GET /api/client/accepted/:id`, `GET /api/client/apps`, `POST /api/client/apps/:id/frame-ticket`, `GET /api/client/apps/:id/frame`, `POST /api/client/apps/:id/tool-broker`, `POST /api/client/apps/:id/db-broker`.

The `/api/auth/*` routes (sign-in, refresh, whoami, logout) are public paths and sit outside both lists.

### 7. Wrong-role answers
These are in the table at the top. The refusal reasons are `member-login`, `client-login` and `admin-login`, and the reason names the **caller's** role. The admin byte routes are the exception: they answer 401 `unauthorized` rather than 403.

### 8. GET /api/team-admin/needs-you (admins only)
- Handler: `server/web/app/api/team-admin/needs-you/route.ts:12-16`. Types: `dto/rows.ts:582-614`.
- A member or client token gets 403 `member-login` or `client-login`.
```ts
export type NeedsYouItem = { id: string; title: string; from: string; at: string };
export type NeedsYou = {
  review: { submitted: number; leftBehind: number; newest: NeedsYouItem | null };
  requests: { open: number; newest: NeedsYouItem | null };
  total: number;   // review.submitted + review.leftBehind + requests.open
};
```
- `requests.newest.from` falls back to `"A team member"` (`packages/content/src/needs-you.ts:30-52`).

### 9. Things from the docs a phone client should know
- **One thread per login, never shared.** Members talk to `team-responder`, which must be exactly at team level; clients talk to `client-responder`, exactly at client level (`docs/member-logins.md:194-215`, `docs/client-logins.md:349-361`). Either responder can be switched off, and you then see `agent: null`.
- **No live stream for member or client chat in version 1.** It is push plus refetch (`docs/mobile-companion-backend.md:597-605`). Apps and QR pairing are also deferred.
- **Client redaction.** No summary, staff name, level or author ever reaches a client. "Private item" placeholders are expected in pages, notes and table cells.
- **Comment authors.** In review talk, a reviewer appears as the brand; in the shared thread, a client appears as its display name, otherwise "A client".
- **Taken-over items.** Lists show them under the title they had when taken. Opening one gets 409 `with-admin`.
- **Client caps** (`docs/client-logins.md:478-511`):
  - A file at most 20 MB (larger gets 413).
  - 200 MB per client, 50 MB uploaded a day, 500 items, 10 submissions a day, 50 waiting for review.
  - A page at most 500 KB and a note at most 50,000 characters (400 `too-large`).
  - Over a storage cap: 409 `quota`.
  - Any JSON body over 8 MB: 413 `body-too-large`.
- **Member caps:** a page document at most 2 MB, a note at most 200,000 characters, 2000 items per space.
- **No banners or notices in the shell.** The web "contract banner" is a client-side check (`docs/member-logins.md:797-799`).
- **Live member events:** `GET /api/member/realtime` is SSE and sends `{ type: 'space_item', id, kind, own }`. Clients have no equivalent.

### Inconsistencies, and what I could not find
1. **Member and client chat refusals differ.** A member's chat-closed 409 and 6-a-minute 429 carry **no `reason`**. The client's carry `chat-closed` and `rate-limited`. The write limit uses `rate-limit` (no "d"), so the strings differ across routes.
2. **`/api/member/space/team` does not exist,** although `member.ts:106,124` mentions it. It isn't in `MEMBER_ROUTES`, and calling it hits `/space/:id`, which answers 400 `Invalid id.`
3. **Item bodies are wider on the wire than the contract** (`MemberSpaceItemBody` page/note, `MemberLibraryItem.table: unknown`):
   - Pages arrive as the full `PageDetail`, with `tags, summary, audience, draftUpdatedAt`.
   - Notes arrive as the full `NoteRow`.
   - Tables arrive as the full `TableDetail`, including `visibility`, `description`, and the column `formula`/`options`.
4. **The `ClientChatThread` doc comment says "newest page first".** The page is in fact the newest 50, sorted ascending within the page.
5. **`docs/client-logins.md:462-465` is out of date.** It says a bearer app cannot load chat images without `?at=`. The code accepts the bearer on every member and client byte route, and `docs/mobile-companion-backend.md` §4 agrees with the code.
6. **`ClientSharedTable.data.aggregates` is not a list of totals.** It is typed as "footer totals" `Record<string,string>`, but it is copied from `TableDoc.aggregates`, which holds the aggregate *kind* (`'sum'`, `'avg'`, …) per column. The client gets no computed totals (`client-shared.ts:110`, `table-model.ts:156-161`).
7. **`ClientAcceptedItem` declares `folderId?` on pages,** but `getClientAcceptedItem` never sends it (`packages/content/src/member-accepted.ts:508-509`).
8. **The shell has no field for whether chat is on and no asset-token expiry.** You have to infer both, as described in item 1.
9. **I found no route a member or client can use to cancel or stop a turn, attach a file to chat, or export markdown.**
