# mudrash

> *A mudra for every codebase. Right in your shell.*

**mudrash** binds a unique color-mudra to each project, so you never invoke an AI coding agent on the wrong codebase.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.2-blue)](https://github.com/tsutsuhiro/mudrash/releases)

**[English](#the-problem)** | **[日本語はこちら](#japanese)**

---

## The problem

When you work across multiple projects and use AI coding agents like Claude Code or Codex, it's easy to lose track of which terminal belongs to which project. A single misdirected prompt can:

- Modify files in the wrong repository
- Pollute the agent's context with irrelevant information
- Reference the wrong codebase as authoritative

Recovering from a misfired prompt costs minutes of focus and often a full context reset.

## What mudrash does

mudrash detects when you launch a coding agent in your shell and gives that terminal a **deterministic color identity** based on the project directory. The signal appears the moment you press enter and persists for the agent's entire lifetime — no setup per project, no IDE plugin, no agent configuration.

```text
~ ▸ cd ~/work/myapp
~/work/myapp ▸ claude        ← terminal background now carries myapp's color
                               (visible even while Claude Code owns the screen)
```

Each codebase keeps its own color across sessions and machines.

## Design principles

mudrash is a **pure decorator layer**. It never:

- Modifies your agent's configuration
- Touches the agent's context window
- Wraps the agent's CLI binary
- Reads or intercepts your input
- Slows down your shell when no agent is running

It only:

- Listens for `claude` or `codex` invocations via your shell's `preexec` hook
- Computes a deterministic color from your `cwd`
- Emits OSC escape sequences (terminal title via OSC 0, terminal background via OSC 11)

If your agent introspects its environment, mudrash is invisible.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/tsutsuhiro/mudrash/main/install.sh | sh
```

Or, from a clone:

```bash
git clone https://github.com/tsutsuhiro/mudrash && ./mudrash/install.sh
```

This adds a small block to your shell's rc file (`.zshrc` only for now). Inspect the script before running.

To uninstall:

```bash
mudrash uninstall
```

## Usage

Once installed, run `claude` or `codex` in any project directory and the terminal will mark itself — no per-project setup, no opt-in.

## Command line

After installation, the `mudrash` CLI is on your `PATH`:

| Command | Effect |
|---|---|
| `mudrash status` | Print install location, env-var values, and a swatch preview of the current cwd's project color |
| `mudrash install` | Re-install / repair the hook block in `~/.zshrc` (idempotent) |
| `mudrash uninstall` | Remove the hook block, delete the install directory, and reset the terminal background |
| `mudrash version` | Print the version string |
| `mudrash --help` | Show usage |

## Configuration

All configuration is via environment variables. Set them in your shell rc file or per-session.

| Variable | Default | Effect |
|---|---|---|
| `MUDRASH_MODE` | `basename` | Project identifier source. Only `basename` is honored today; `path` mode (which would use the absolute path so identically-named projects in different directories get different colors) is planned. |
| `MUDRASH_AGENTS` | `"claude codex"` | Space-separated list of agent commands to detect. Add aliases or other agents here. |
| `MUDRASH_DISABLE` | unset | Set to `1` to temporarily disable mudrash without uninstalling. Gates both the OSC 0 title and the OSC 11 background. |

## How it works

mudrash hooks into your shell's `preexec` event. When you run a command:

1. The hook checks if the command starts with one of `MUDRASH_AGENTS`
2. If yes, it computes `key = basename($PWD)` (path mode is planned)
3. Hashes the key with SHA-1 and takes the first 4 hex chars as `hue` (mod 360)
4. Applies "knee zone" correction:
   - hues 50–70 shift +30 (avoids muddy yellow-green)
   - hues 270–290 shift +25 (avoids hard-to-read reddish-purple)
5. Generates a subdued background color: `HSL(hue, 30%, 14%)` — dark enough
   that text on top stays readable, saturated enough that distinct projects
   are visually distinguishable
6. Emits OSC 0 (terminal title) with the project label — the title gets
   overwritten by most full-screen TUI agents, so this signal is fleeting
7. Emits OSC 11 (terminal background) — the primary signal. Survives
   full-screen TUI agents like Claude Code because such TUIs render text
   over the terminal's default background without painting it themselves

For non-matching commands, the hook returns immediately with O(1) cost.

The HSL math runs in `awk`. The hash uses `shasum`. No runtime dependencies beyond POSIX tools.

## Compatibility

### Shells

| Shell | Status |
|---|---|
| zsh | ✅ supported |
| bash | not yet supported |
| fish | not yet supported |

### Terminal emulators

| Terminal | Title (OSC 0) | Background (OSC 11) |
|---|---|---|
| iTerm2 | ✅ | ✅ |
| Windows Terminal | ✅ | ✅ |
| Alacritty | ✅ | ✅ |
| WezTerm | ✅ | ✅ |
| VS Code / Cursor integrated | ✅ | ✅ |
| GNOME Terminal | ✅ | ✅ |
| macOS Terminal.app | ✅ | ✅ |

OSC 11 (the terminal background) is the primary signal. Most full-screen TUI agents overwrite the OSC 0 title at startup, so the title is only visible at the moment of invocation; the background tint persists.

## FAQ

**Why a shell hook instead of an IDE extension?**
A shell hook works in every IDE, in standalone terminals, and across machines with no IDE-specific code. Since `claude` and `codex` always run inside a shell, this is the most universal point of intercept.

**Why not just use [Peacock](https://marketplace.visualstudio.com/items?itemName=johnpapa.vscode-peacock)?**
Peacock colors IDE chrome (status bar, title bar) and is VS Code only. mudrash colors the terminal where the agent actually runs, fires only when the agent launches, and works across any shell and any IDE — including standalone terminals.

**Does it touch my agent's behavior or context?**
No. mudrash only emits ANSI/OSC escape sequences (terminal title and background). It does not modify your `PROMPT`, your agent's stdin/stdout, or the agent's environment. The agent has no way to detect mudrash exists from inside its own process.

**What if I use an alias or wrapper for `claude`?**
Add your alias name to `MUDRASH_AGENTS`. The hook matches against the first word of the command line.

**Why does the color persist after the agent exits?**
By design. The terminal becomes "branded" for that project, so re-launches stay consistent. There is no reset on agent exit. To restore the terminal default, run `mudrash uninstall` or `printf '\033]111\007'` (one-line reset).

**Why doesn't mudrash modify my `PROMPT`?**
Touching `$PROMPT` would require `setopt PROMPT_SUBST` and interfere with themes (oh-my-zsh, powerlevel10k, starship). A prefix would also become stale because it could only refresh on agent invocation, not on `cd`. The OSC 11 background tint already provides the same identity signal across all states (shell, agent, post-exit) without any side effects on your prompt.

## Acknowledgements

The name comes from *mudra* (मुद्रा), the Sanskrit term for symbolic hand gestures used in meditation and ritual. Each codebase deserves its own.

Inspired by [Peacock](https://github.com/johnpapa/vscode-peacock)'s per-workspace color idea, but reimagined as a shell-level decorator that targets where the agent actually runs.

## License

MIT — see [LICENSE](./LICENSE).

---

<a id="japanese"></a>

# 日本語版

**[English version ↑](#the-problem)**

> *コードベースごとのムドラ。シェルの中で。*

**mudrash** は、各プロジェクトに固有の「色のムドラ」を割り当てることで、AI コーディングエージェントを誤ったコードベースに対して起動してしまう事故を防ぎます。

## 解決する問題

複数のプロジェクトを並行して進めながら Claude Code や Codex などの AI エージェントを使うと、どのターミナルがどのプロジェクトのものか見失いがちです。プロンプトを誤って投げると:

- 別のリポジトリのファイルが変更される
- エージェントのコンテキストが無関係な情報で汚染される
- 別のコードベースが「正」として参照される

誤投入から復旧するには集中力数分とコンテキストリセットのコストがかかります。

## mudrash がやること

mudrash はシェルでコーディングエージェントを起動した瞬間を検知し、そのターミナルにプロジェクトディレクトリ由来の**決定的な色アイデンティティ**を与えます。シグナルはエンターを押した瞬間に現れ、エージェントの実行中もずっと残り続けます。プロジェクトごとのセットアップ、IDE プラグイン、エージェントの設定変更は一切不要です。

```text
~ ▸ cd ~/work/myapp
~/work/myapp ▸ claude        ← ターミナル背景が myapp の色に染まる
                               （Claude Code が画面を占有していても見える）
```

各コードベースは、セッションをまたいでもマシンをまたいでも、同じ色を保ちます。

## 設計原則

mudrash は **純粋なデコレータ層** です。以下を一切行いません:

- エージェントの設定変更
- エージェントのコンテキストウィンドウへの介入
- エージェント CLI バイナリのラッパー化
- 入力の読み取りや傍受
- エージェント未起動時のシェル速度低下

行うのは:

- シェルの `preexec` フック経由で `claude` / `codex` の起動を検知
- `cwd` から決定的な色を計算
- OSC エスケープシーケンスを送出（OSC 0 でターミナルタイトル、OSC 11 でターミナル背景）

エージェントが自身の環境を introspect しても、mudrash は見えません。

## インストール

```bash
curl -fsSL https://raw.githubusercontent.com/tsutsuhiro/mudrash/main/install.sh | sh
```

クローンから:

```bash
git clone https://github.com/tsutsuhiro/mudrash && ./mudrash/install.sh
```

シェルの rc ファイル（現状 `.zshrc` のみ）に小さなブロックを追加します。実行前にスクリプトを確認してください。

アンインストール:

```bash
mudrash uninstall
```

## 使い方

インストール後、任意のプロジェクトディレクトリで `claude` または `codex` を起動するだけで、ターミナルがそのプロジェクト用にマークされます。プロジェクトごとのセットアップやオプトインは不要です。

## コマンドライン

インストール後、`mudrash` CLI が `PATH` 上で利用可能になります:

| コマンド | 効果 |
|---|---|
| `mudrash status` | インストール場所、env 変数、現 cwd のプロジェクト色プレビュー（swatch）を表示 |
| `mudrash install` | `~/.zshrc` のフックブロックを再インストール / 修復（冪等） |
| `mudrash uninstall` | フックブロック削除、インストールディレクトリ削除、ターミナル背景リセット |
| `mudrash version` | バージョン表示 |
| `mudrash --help` | ヘルプ表示 |

## 設定

すべての設定は環境変数経由です。シェル rc ファイル、またはセッション単位で設定してください。

| 変数 | デフォルト | 効果 |
|---|---|---|
| `MUDRASH_MODE` | `basename` | プロジェクト ID のソース。現状 `basename` のみ honor される（同名プロジェクトはマシンをまたいでも同じ色になる）。`path` モード（絶対パスを使用、同名でも別ディレクトリなら別色）は計画段階。 |
| `MUDRASH_AGENTS` | `"claude codex"` | 検出対象コマンドの空白区切りリスト。エイリアスや他のエージェントを追加可能。 |
| `MUDRASH_DISABLE` | unset | `1` でアンインストールせずに mudrash を一時無効化。OSC 0 タイトルと OSC 11 背景の両方を gate します。 |

## 仕組み

mudrash はシェルの `preexec` イベントにフックします。コマンドを実行する際:

1. コマンドが `MUDRASH_AGENTS` のいずれかで始まるかチェック
2. マッチすれば `key = basename($PWD)` を計算（path モードは計画段階）
3. キーを SHA-1 でハッシュ化、先頭 4 hex chars を `hue` として取得（mod 360）
4. 「ニーゾーン補正」を適用:
   - hue 50–70 は +30 シフト（くすんだ黄緑を避ける）
   - hue 270–290 は +25 シフト（読みにくい赤紫を避ける）
5. 抑えめの背景色を生成: `HSL(hue, 30%, 14%)` — 上に乗るテキストが読めるくらい暗く、別プロジェクト同士が見分けられる程度の彩度
6. OSC 0（ターミナルタイトル）を送出 — タイトルは多くの full-screen TUI エージェントに上書きされるので fleeting なシグナル
7. OSC 11（ターミナル背景）を送出 — **主シグナル**。Claude Code 等の TUI は背景を自前で塗らずターミナル default の上にテキストを描画するため、tint が透けて見える

エージェントにマッチしないコマンドではフックは即 return（O(1) コスト）。

HSL 計算は `awk`、ハッシュは `shasum` 使用。POSIX ツール以外の runtime 依存なし。

## 互換性

### シェル

| シェル | 状態 |
|---|---|
| zsh | ✅ 対応 |
| bash | 未対応 |
| fish | 未対応 |

### ターミナルエミュレータ

| ターミナル | タイトル (OSC 0) | 背景 (OSC 11) |
|---|---|---|
| iTerm2 | ✅ | ✅ |
| Windows Terminal | ✅ | ✅ |
| Alacritty | ✅ | ✅ |
| WezTerm | ✅ | ✅ |
| VS Code / Cursor integrated | ✅ | ✅ |
| GNOME Terminal | ✅ | ✅ |
| macOS Terminal.app | ✅ | ✅ |

OSC 11（ターミナル背景）が主シグナル。多くの full-screen TUI エージェントは起動時に OSC 0 タイトルを上書きするため、タイトルは起動の瞬間にしか見えませんが、背景 tint は持続します。

## FAQ

**なぜ IDE 拡張ではなくシェルフックなのか？**
シェルフックはあらゆる IDE、スタンドアロンターミナル、複数マシンで IDE 固有のコードなしに動作します。`claude` と `codex` は常にシェルの中で動くため、最も普遍的な intercept ポイントです。

**[Peacock](https://marketplace.visualstudio.com/items?itemName=johnpapa.vscode-peacock) で良いのでは？**
Peacock は IDE 自体の chrome（ステータスバー、タイトルバー）に色を付ける VS Code 専用ツールです。mudrash はエージェントが実際に動くターミナルに色を付け、エージェント起動時にだけ発火し、任意のシェル・任意の IDE（スタンドアロンターミナル含む）で動作します。

**エージェントの動作や context に介入する？**
いいえ。mudrash は ANSI/OSC エスケープシーケンス（ターミナルタイトルと背景）のみ送出します。`$PROMPT`、エージェントの stdin/stdout、エージェントの環境変数のいずれも変更しません。エージェントは自身のプロセス内から mudrash の存在を検知する手段を持ちません。

**`claude` のエイリアスやラッパーを使っている場合は？**
エイリアス名を `MUDRASH_AGENTS` に追加してください。フックはコマンド行の最初の単語にマッチします。

**エージェント終了後も色が残るのは？**
仕様です。ターミナルがそのプロジェクト用に "branded" されるため、再起動しても同じ色を保ちます。エージェント終了でのリセットはありません。ターミナルをデフォルトに戻すには `mudrash uninstall` または `printf '\033]111\007'`（1 行リセット）を実行してください。

**`PROMPT` を改変しないのはなぜ？**
`$PROMPT` を触ると `setopt PROMPT_SUBST` が必要になり、テーマ（oh-my-zsh、powerlevel10k、starship）と衝突します。プレフィックス方式はエージェント起動時にしか更新できないので `cd` 後に古い情報が残る問題もあります。OSC 11 背景 tint は同じアイデンティティシグナルをシェル時・エージェント時・終了後すべての状態で副作用なく提供します。

## 内部動作の詳細

インストール → 起動 → 通常コマンド → エージェント起動 → アンインストールまでの完全フロー。

### 1. `./install.sh` 実行時

**1-1. シェル検証** (`install.sh:32-39`): `$SHELL` 末尾が `/zsh` でない（bash、fish 等）なら即終了。

**1-2. インストール先決定** (`install.sh:43-50`):
1. 第一候補 `~/.local/share/mudrash/` を `mkdir -p` 試行
2. 失敗したら `~/.mudrash/` にフォールバック

**1-3. ファイルコピー** (`install.sh:54-68`):
```
~/.local/share/mudrash/
├── mudrash.zsh           ← preexec フック本体
├── lib/{color,hash}.zsh  ← 色 + ハッシュロジック
├── bin/mudrash           ← CLI
└── install.sh            ← 再インストール用
```
既存 `lib/*.zsh` は `rm -f` で除去後コピー（古いファイルを残さない）。

**1-4. `~/.zshrc` 編集** (`install.sh:72-95`): 既存 marker block があれば削除してから以下を追記:
```sh
# >>> mudrash >>>
export PATH="/Users/<user>/.local/share/mudrash/bin:$PATH"
source "/Users/<user>/.local/share/mudrash/mudrash.zsh"
# <<< mudrash <<<
```
余分な空行は `awk` で潰す。`\$PATH` は escape 済 → ファイル上は literal `$PATH`、zsh が source 時に展開。

### 2. `.zshrc` source 時（新規 zsh 起動毎）

**2-1. PATH 追加**: `/Users/<user>/.local/share/mudrash/bin` が `PATH` 先頭に追加 → `mudrash` コマンド利用可。

**2-2. `mudrash.zsh` source**: 順番に実行されるのは:
1. `MUDRASH_VERSION='0.2.0'` 定数定義
2. `_MUDRASH_DIR` 自身の絶対パス解決
3. `lib/hash.zsh`、`lib/color.zsh` を source
4. キャッシュ変数 3 つを空文字で初期化（`_MUDRASH_CACHED_PWD/LABEL/BG`）
5. `_mudrash_refresh_cache()` と `_mudrash_preexec()` 定義
6. `add-zsh-hook preexec _mudrash_preexec` でフック登録

**この時点ではターミナル背景、タイトル、`PROMPT` いずれも未変更。**

### 3. 通常コマンド実行時（`ls`、`git status` 等）

`_mudrash_preexec "<コマンド行>"` が発火し:

1. `[[ -n "$MUDRASH_DISABLE" ]] && return` — DISABLE なら即 return
2. `cmd=${1%% *}; cmd=${cmd:t}` — 最初の単語の basename を取得（`"ls"`、`"git"`、`"claude"`）
3. `case " $agents " in *" $cmd "*) ;; *) return ;;` — エージェントリストにマッチしないなら return

**fork なし、I/O なし、サブミリ秒で完了**。`ls`、`vim`、`git status` 等はここで止まる。

### 4. エージェント起動時（`claude`、`codex` 等）

**4-1. cache refresh** (`mudrash.zsh:30-43`):
```zsh
if [[ "$PWD" == "$_MUDRASH_CACHED_PWD" && -n "$_MUDRASH_CACHED_BG" ]]; then
    return    # cwd 不変 → 再計算不要
fi
local label hue
label=${PWD:t}                                # /Users/hiroki/dev/myapp → "myapp"
hue=$(mudrash_hue "$label")                   # sha1 → hex → mod 360 → knee 補正
_MUDRASH_CACHED_LABEL=$label
_MUDRASH_CACHED_BG=$(mudrash_bg_color "$hue") # HSL(hue, 30%, 14%) → hex
_MUDRASH_CACHED_PWD=$PWD
```
初回 or cwd 変化時のみ `shasum` と `awk` を fork（数 ms）。それ以外はキャッシュヒットで即 return。

**4-2. OSC 0 emit — ターミナルタイトル**
```zsh
printf '\033]0;%s ▸ %s\007' "$_MUDRASH_CACHED_LABEL" "$cmd"
```
タブ/ウィンドウタイトルが `myapp ▸ claude` に変更。**Claude Code 起動と同時に上書きされるため一瞬しか見えない。**

**4-3. OSC 11 emit — ターミナル背景色（主シグナル）**
```zsh
printf '\033]11;#%s\007' "$_MUDRASH_CACHED_BG"
```
ターミナル背景が「myapp の決定色」に変更。**Claude Code は背景を塗らないので TUI 中も背景 tint が見える。**

**4-4. その後**:
- エージェント起動 → TUI が画面占有
- mudrash の関与はここで完全終了（decorator 原則）
- エージェント終了 → シェル復帰 → 背景は myapp 色のまま (branded)
- 同ターミナルで再度 `claude` → cache hit → OSC 11 emit 1 回のみ

### 5. `mudrash uninstall` 実行時 (`bin/mudrash:110-148`)

```sh
cmd_uninstall() {
    printf '\033]111\007'      # OSC 111: 背景をデフォルトに reset

    # ~/.zshrc から marker block を awk で除去
    # ...

    # インストール先削除（2 段階チェック）
    if [ -f "$MUDRASH_HOME/mudrash.zsh" ] && [ -f "$MUDRASH_HOME/bin/mudrash" ]; then
        case "$MUDRASH_HOME" in
            */.local/share/mudrash|*/.mudrash)
                rm -rf "$MUDRASH_HOME"   # 認知された場所のみ削除
                ;;
        esac
    fi
}
```

実行後:
- ターミナル背景: default 復帰
- `~/.zshrc`: mudrash block 完全消去、ユーザの他設定は無傷
- `~/.local/share/mudrash/`: 完全削除

### 6. ファイル / 状態への副作用一覧

| 対象 | install 時 | source 時 | preexec 時 | uninstall 時 |
|---|---|---|---|---|
| `~/.zshrc` | marker block 追記 | 読まれる | — | block 削除 |
| `~/.local/share/mudrash/` | 新規作成 + コピー | — | — | 削除 |
| `$PATH` | — | install 先/bin 追加 | — | (新規 shell から消える) |
| ターミナル背景 (OSC 11) | — | — | エージェント時のみ変更 | reset |
| ターミナルタイトル (OSC 0) | — | — | エージェント時のみ変更 | — |
| `PROMPT` 環境変数 | — | — | **無変更** | — |
| `~/.claude/` 等の agent 設定 | **無関係** | **無関係** | **無関係** | **無関係** |

## 謝辞

`mudra`（मुद्रा）はサンスクリット語で、瞑想や儀礼で使われる象徴的な手の所作を指します。コードベースもそれぞれ固有のしるしを持つに値します。

[Peacock](https://github.com/johnpapa/vscode-peacock) のワークスペースごとに色を付けるアイデアにインスパイアされていますが、IDE chrome ではなくエージェントが実際に動くシェルレベルのデコレータとして再構成しました。

## ライセンス

MIT — [LICENSE](./LICENSE) を参照。

