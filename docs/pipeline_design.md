# データパイプライン設計

## 目的と実装範囲

TheLookのeコマースデータ7テーブルを対象に、JSONで定義した加工ルールに従ってCSVを加工し、Parquet形式でAWS S3へ保存した後、Snowflakeへ取り込む。

各処理はDocker上のPythonからコマンドで起動する。全工程の一括実行、定期実行、監視・通知は未実装。「自動化」は、起動した各処理内での繰返し処理・SQL実行を指す。

## データの流れ

1. Kaggleから取得した7CSVを`data/raw/`に配置する。
2. `src/loaders/loa_s3.py`で元CSVをS3の`raw/`へ保存する。加工前の原本を保持する目的で、元データを自動修正しない。
3. `src/cleansing/main.py`でローカルCSVを加工し、`data/processed/`へParquetを出力する。
4. `src/loaders/upload_s3.py`でParquetをS3の`processed/`へ保存する。
5. `src/loaders/snowflake_loader.py`から7テーブルのCOPY SQLを順次実行し、`THELOOK_DB.STAGING`へ取り込む。
6. 検証SQLとPythonによる読戻しで、件数・型・変換結果・整合性を確認する。

現実装の加工元はローカルCSVであり、S3のrawからダウンロードして加工する構成ではない。loa_s3.pyの保存方向は、仕様書で省略されている部分を演習上の判断で補ったもの。

## データソースと粒度

取得元：https://www.kaggle.com/datasets/daichiuchigashima/thelook-ecommerce

初期に試したBigQueryの取得結果と混在させず、今回のKaggleスナップショットを件数の基準とする。データ本体はGitの管理対象から除外する。再配布の可否は未確認で、データをリポジトリへ公開しない。

| テーブル | 1行の単位 | 行数 |
| --- | --- | ---: |
| distribution_centers | 物流拠点 | 10 |
| products | 商品 | 29,120 |
| inventory_items | 在庫の商品1点 | 487,901 |
| orders | 注文 | 124,923 |
| order_items | 商品1点の注文明細 | 180,952 |
| users | ユーザー | 100,000 |
| events | 行動イベント | 2,420,738 |
| 合計 | | 3,343,644 |

## 加工処理と設定の分離

`cleaning_data.py`に共通の変換処理を実装し、`config/column_config.json`にテーブルごとの対象列を記述する。

| テーブル | 日時変換 | 小文字化 | SHA-256 |
| --- | --- | --- | --- |
| users | created_at | email, first_name, last_name | email |
| products | なし | category, department | なし |
| inventory_items | created_at, sold_at | product_category, product_department | なし |
| orders | created_at, returned_at, shipped_at, delivered_at | status | なし |
| order_items | created_at, shipped_at, delivered_at, returned_at | status | なし |
| events | created_at | なし | なし |
| distribution_centers | なし | なし | なし |

既存の加工の対象列を追加・変更するときは、共通処理を変えずJSONで対応できる。新しい加工種類を追加するときはPython側の実装も必要。設定変更後は列の存在と出力内容を再確認する。

変換順は日時変換、小文字化、ハッシュ化。emailは小文字化してからハッシュ化し、大文字小文字だけが違う入力から同じ値を得る。小文字化は演習で選択したルールであり、すべての業務データへ無条件に適用する方針ではない。

ハッシュはUTF-8の入力をSHA-256へ変換した64桁の16進文字列。欠損は欠損として保持する。ソルト等を用いていないため、完全な匿名化を保証するとは説明しない。氏名・住所等を含むデータ全体の匿名化も実施していない。

## チャンク・型・保存

- 通常は10,000行単位で処理し、全データを一度にDataFrameへ読み込まない。メモリ使用量の実測は未実施。
- 日時は`pd.to_datetime(..., format="mixed", errors="coerce", utc=True)`で変換する。初期実装では小数秒の形式が混在する日時2,494件が欠損になり、原因調査後にmixed指定で修正した。
- `errors="coerce"`は変換不能値を欠損にするため、正常終了だけでは品質を保証できない。元の欠損数と保存後の欠損数を照合する。
- usersとeventsのpostal_codeは文字列として読み、先頭の0を保持する。events.user_idは欠損可能な整数として読み込む。
- Arrowの最初のチャンクのスキーマを後続にも適用する。全列を外部定義した完全なスキーマ契約ではない。
- Snappy圧縮のParquetへ保存する。インデックスは出力しない。
- 途中は`.part`へ書き、正常終了後に正式名へ置き換える。書込途中のエラーでは正式ファイルを作らず、閉じた途中ファイルを残す検証を行った。同一出力名への並列実行は想定していない。

## S3・Snowflakeへの取込み

S3バケットとSnowflakeは東京リージョンを使用する。rawとprocessedは同じバケットのプレフィックスで分離する。

SnowflakeはStorage IntegrationとAWSの読取ロールを使用し、processed配下を参照する。Pythonローダーは専用サービスユーザーの鍵認証で接続し、AWSのアクセスキーをSnowflakeへ渡さない。権限の詳細は別途RBAC設計書に記載する。

Parquetのファイル形式は`USE_LOGICAL_TYPE=TRUE`。日時列の取込先はTIMESTAMP_LTZ、セッションはUTC。TIMESTAMP_LTZの表示はセッションのタイムゾーンに依存する。postal_codeはVARCHAR、元の小数値はFLOATとして保持し、業務上の金額丸め規則は追加していない。

COPYではファイル名を明示し、`MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE`、`ON_ERROR=ABORT_STATEMENT`、`FORCE=FALSE`を指定する。

## 再実行と失敗時の範囲

- 同じ未変更ファイルを同じテーブルへ再COPYすると、ロード履歴によってLOAD_SKIPPEDとなることを確認した。履歴には保持期間があり、変更ファイルやテーブルの再作成まで含む普遍的な重複防止ではない。
- PythonはSQLを順番に実行し、クエリIDと結果を表示する。途中のSQL例外で後続処理を停止する。
- 7文全体を単一トランザクションにはしていない。途中で失敗しても、それ以前に確定したCOPYは取り消されない。
- 正常SELECT、意図した不正SELECT、後続SELECTの順に実CLIへ渡し、非ゼロ終了と後続未実行を確認した。
- 一時テーブルへの初回10行ロードと、既存7テーブルへの再実行を確認した。全7テーブルを空の新環境から構築する手順一式の実証は未実施。

## 検証結果と既知の課題

- 7テーブルの保存・読戻し・Snowflake格納件数はすべて一致。
- 主キー候補のNULLと余分な重複行は全7テーブルで0。DDLの制約による自動保証ではなく、検証時点の結果。
- 9つの参照で、非NULLの参照値に対応しない親レコードは0。
- 全12日時列のUTCタイムスタンプ型と欠損数の保持を確認。文字列加工は元CSVから求めた期待値と全件一致。加工対象外列も全件一致。
- events.user_idのNULLは1,124,065件。すべて匿名ユーザーであるとは断定しない。
- 注文56はorders.user_id=56、明細88〜91はorder_items.user_id=44。どちらのユーザーも存在するため、参照チェックだけでは検出できない。正しい値を断定せず原本を保持し、顧客別集計で結果が変わる課題として記録する。
- 明細と在庫の商品ID不一致は0、注文個数と明細件数の不一致は0。
- 検証SQLは結果を表示する。NG値を検知して実行を自動失敗させる品質ゲートではない。
- 日時の全値・小数秒の独立照合、メモリ実測、別PCでの再現、ネットワーク障害・鍵期限切れの試験は未実施。

## 実測値

- 元CSV合計526,472,778bytes、加工後Parquet合計239,016,879bytes。約54.60%減だが加工内容も異なるため、純粋なファイル形式だけの圧縮比較ではない。
- 手動COPYの報告時間：products約3秒、events約17秒。再現性を測定した性能ベンチマークではない。
- 直近3日間の反映済み計算履歴はTHELOOK_WHで0.586875 credits。個別COPYの費用や保存料等を含む総請求額ではない。

## 今後の改善候補

全工程の一括実行・定期実行、品質判定の自動化、より明示的な型定義、アップロード用AWS権限の絞込み、データ更新時の取込方式、分析向け公開層と既知不一致の扱いを検討する。これらは現時点の実装実績には含めない。
