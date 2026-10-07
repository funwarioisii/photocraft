# PhotoCraft のローカル MCP

PhotoCraft の既存の Rust MCP サーバーを AI クライアントから起動するためのランチャーです。
標準入出力で接続し、HTTP サーバーの常駐は不要です。Bash のある環境で利用できます。

| サーバー | 用途 | セッション |
|---|---|---|
| `photocraft` | 画像の加工、一括編集、保存、画像プレビュー | MCP 接続ごとの独立したエンジン |
| `photocraft_gui` | 表示中の文書、ブラシ、パネル、メニュー、画面取得 | 起動中の GUI と同じ文書 |

## Codex に登録

```sh
cargo build --locked -p photocraft-cli
bash scripts/mcp/register-codex.sh
```

`photocraft` と `photocraft_gui` の登録を追加・更新します。他の名前の MCP 設定は保持します。
登録を読み込むには MCP クライアントを再接続してください。まずは画面なしの `photocraft` を使います。
ランチャーはチェックアウトから実行ファイルを見つけ、debug がなければ release を使います。

他の MCP クライアントでは次の `mcpServers` を設定に追加し、`/absolute/photocraft` を実際のチェックアウトへ置き換えます。

```json
{
  "mcpServers": {
    "photocraft": {
      "command": "/bin/bash",
      "args": ["/absolute/photocraft/scripts/mcp/headless.sh"]
    },
    "photocraft_gui": {
      "command": "/bin/bash",
      "args": ["/absolute/photocraft/scripts/mcp/gui.sh"]
    }
  }
}
```

必要ならクライアントの設定で起動待ち時間を 45 秒、ツール実行の待ち時間を 300 秒にします。
長時間の編集は下記の非同期ジョブを使います。

## GUI の準備

```sh
cargo build --locked -p photocraft
mkdir -p temp/mcp/work
./target/debug/photocraft --control 7878 --control-token-file "$PWD/temp/mcp/control.token" \
  --automation-read-root "$PWD/temp/mcp/work" --automation-write-root "$PWD/temp/mcp/work"
```

アプリがプライベートトークンを作成します。次に GUI MCP を接続します。
準備済みクラウド環境では既存の `ensure-gui.sh` を再利用し、仮想ディスプレイと CPU 描画のアプリを自動起動します。
GUI 起動用のカスタムスクリプトも指定できます。起動時の診断は標準エラーへ出し、MCP の標準出力は JSON-RPC 専用にします。

| 環境変数 | 用途 |
|---|---|
| `PHOTOCRAFT_MCP_CLI` | 使用する `photocraft-cli` のパス |
| `PHOTOCRAFT_MCP_ENV_FILE` | ツールチェーン・ライブラリの初期化用シェルファイル |
| `PHOTOCRAFT_MCP_WORKSPACE` | 画面なしの読み書きルート |
| `PHOTOCRAFT_MCP_GUI_ADDRESS` | GUI 制御アドレス（既定 `127.0.0.1:7878`、loopback のみ） |
| `PHOTOCRAFT_MCP_TOKEN_FILE` | GUI が使うプライベートトークンファイル |
| `PHOTOCRAFT_MCP_GUI_START_SCRIPT` | GUI 接続前に実行する起動スクリプト（`flock` が必要） |

これらを MCP クライアントの環境変数設定に指定できます。トークンの値を設定やチャットへ貼る必要はありません。
GUI の読み書きルートはアプリ起動時に指定します。MCP 側の `PHOTOCRAFT_MCP_WORKSPACE` は GUI の権限を変更しません。

## AI の作業手順

既定の作業ディレクトリはチェックアウト内の `temp/mcp/work`（gitignored）です。準備済みクラウド環境では `/workspace/photocraft-runtime/work` を使います。
画像をこのディレクトリに置き、MCP には `input.png` や `job-01/output.png` のような相対パスを渡します。
画面なしの別プロジェクトは `bash scripts/mcp/headless.sh /absolute/project/path` で読み書きのルートを変更できます。

1. `doc_open` または `doc_new` で文書を用意する。
2. `command_list` に `filter` を渡して操作を検索する。戻り値の `params` 説明を読み、コマンド ID とパラメーターを確認する。
3. `command_run` または `command_batch` で操作する。名前やパラメーターを推測せず検索結果を使う。
4. `doc_inspect` でレイヤー、サイズ、選択範囲などを確認し、`doc_render_preview` で結果を画像として確認する。
5. `doc_save` で `.pcraft` に編集可能な状態を保存し、`doc_export` で PNG/JPEG/PSD 等を書き出す。戻り値の `warnings` を読む。
6. 次の入力に移る前に `doc_close` する。GUI では `command_run` の `id: "file.close"` を使う。

セッションを切断すると未保存の文書は失われます。長い作業では途中の `.pcraft` を保存してください。
複数文書の `index` は `session_list` で再確認します。閉じると番号が変わります。
`doc_select` と `doc_close` は画面なし用です。GUI の文書選択は `ui_inspect` と制御プロトコルを確認して行います。
GUI の `doc_render_preview` は文書単体ではなくアプリ画面を返します。

## 編集の例

`doc_new`:

```json
{"width":640,"height":480,"background":"white","name":"AI work"}
```

`command_batch`（最大 256 ステップ。失敗時は既定で停止します。処理済みの操作は巻き戻されません）:

```json
{"steps":[
  {"id":"layer.new.layer","params":{"name":"Ink"}},
  {"id":"paint.stroke","params":{"points":[[50,50,1.0],[500,400,1.0]],"size":6,"color":"#ff0000"}}
]}
```

`doc_render_preview`: `{"max_side":512}`。返り値の MCP image コンテンツが PNG 画像です。
`doc_save`: `{"path":"work.pcraft"}`。
`doc_export`: `{"path":"output.png"}`。

時間がかかる操作は `command_run` で `wait:false` を指定し、返された `job` を `jobs_list` で監視します。
`done` を確認してから保存や次の編集に進みます。`failed` は理由を確認し、取り消しには `jobs_cancel` の `job` を指定します。
`command_batch` の各ステップにも `wait:false` を指定できますが、後続の編集はジョブ完了後に別の呼び出しで実行してください。

同じ MCP セッションの編集は順番に実行します。独立した複数 MCP 接続を使えば、文書状態を分離して作業できます。
ファイル名を接続間で分け、同じファイルへの同時書き込みを避けます。GUI 接続は同じアプリを共有します。

## GUI を使う場合

`ui_inspect` で現在の文書と UI 状態を読み、`ui_set` でツールなどを選択、`ui_pointer` で文書座標のポインター操作、
`ui_menu_invoke` でメニュー操作、`ui_screenshot` で画面を取得できます。
`control_call` は `docs/control-protocol.md` に載る制御メソッドを呼びます。
GUI 制御のプライベートトークンはファイル経由で読みます。値を設定やチャットへ貼り付ける必要はありません。

## 検証

既存の Rust テストで MCP ツールとエージェントによる編集タスクを検証できます。

```sh
cargo test --locked -p photocraft-automation --test mcp --test agent_tasks
```

クラウド環境ではランチャーの実際の MCP 通信で、10 枚の編集・保存・書き出し、レイヤー再読み込み、PNG プレビュー、
非同期処理、接続ごとの状態分離、GUI 起動・ブラシ操作・画面取得も検証しています。
未保存の作業を持つ GUI に検証を流し込まず、作業用文書を用意してください。
