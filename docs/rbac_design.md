# 権限・認証設計

## 目的と現在の範囲

環境を管理する操作と、日常の取込み処理を分け、専用ユーザーには必要なロールを付与する。Snowflake内の権限、AWSロールへの接続、S3オブジェクトへの権限をそれぞれ設定する。

これは演習で実装・確認した構成の記録であり、組織全体の権限監査や本番運用の実績を示すものではない。

## Snowflakeのロール構成

```
SYSADMIN
├── THELOOK_ETL_ROLE
└── THELOOK_ANALYST_ROLE
```

両カスタムロールをSYSADMINへ付与する。ETLとANALYSTは親子関係にせず、互いの権限を継承させない。図は今回作成したカスタムロール部分のみを示す。

| ロール | 現在の用途・権限 |
| --- | --- |
| SECURITYADMIN | カスタムロールと専用ユーザーの作成、ロール付与 |
| SYSADMIN | THELOOK_WH、THELOOK_DB、各スキーマの所有・管理。Integrationの所有権も移管 |
| ACCOUNTADMIN | Storage Integrationの初期作成などの管理操作 |
| THELOOK_ETL_ROLE | THELOOK_WH、THELOOK_DB、STAGING、IntegrationのUSAGE。STAGINGでTABLE・FILE FORMAT・STAGEを作成 |
| THELOOK_ANALYST_ROLE | THELOOK_WH、THELOOK_DB、ANALYTICSのUSAGE |

ETLロールは自ら作成したSTAGINGのテーブル、ファイル形式、ステージを所有する。そのため権限は既存表への読取・書込だけではなく、取込み用オブジェクトの作成・変更も含む。演習では構築用と日常実行用のETLロールをさらに分割していない。

ANALYTICSは分析向け公開用として分離したが、現在はテーブル・ビューの公開とSELECT付与を実施していない。ANALYSTには分析結果を実際にSELECTできる状態まで整備していない。USAGEは対象を利用する入口の権限であり、テーブルのSELECT権限とは別。

スキーマ分離は加工用と分析用のオブジェクト・権限の管理境界を作る。スキーマを分けるだけで計算資源の競合がなくなるわけではない。両ロールは同じTHELOOK_WHを使用する。

## ユーザーとPython接続

- 個人の管理操作用ユーザー：KEIMAEDA。
- Python専用ユーザー：THELOOK_PIPELINE_USER、TYPE=SERVICE。
- 専用ユーザーにTHELOOK_ETL_ROLEを付与。初期ロールも同ロールとし、セカンダリロールは無効。
- 初期ウェアハウスはTHELOOK_WH、初期名前空間はTHELOOK_DB.STAGING。
- Python接続後のCURRENT_USER、CURRENT_ROLE、CURRENT_SECONDARY_ROLES等で実際の接続主体を確認した。

専用ユーザーの鍵ペア認証を使用する。暗号化した秘密鍵はUbuntuのリポジトリ外に置き、権限600で保持する。コンテナには読取専用で渡し、パスフレーズは実行時の非表示入力から環境変数へ渡す。JSONには接続先、ロール、コンテナ内の秘密鍵パス等を記載し、秘密鍵本文とパスフレーズは記載しない。

公開鍵はSnowflakeユーザーへ登録する。04_pipeline_user.sqlの登録文はプレースホルダー付きコメントであり、新規環境では公開鍵本文への置換と登録が必要。既存ユーザーの公開鍵を不用意に上書きしない。

環境変数と読取専用マウントを、秘密管理サービスと同等の保護とは扱わない。鍵のローテーション、ネットワーク制限、秘密管理サービスとの連携は未実装。

## AWS・Snowflakeの接続経路

```
Snowflake Storage Integration
  → Snowflake側IAMユーザーがsts:AssumeRole
  → TheLookSnowflakeReadRole
  → S3のprocessed配下をLIST・READ
```

Storage Integration：THELOOK_S3_INTEGRATION

AWS読取ロール：arn:aws:iam::324475349753:role/TheLookSnowflakeReadRole

S3保存先：s3://thelook-pipeline-keisuke-20261028/processed/

Integrationの許可先をprocessed配下に限定する。AWSロールのIAMポリシーも次の範囲とし、S3の書込・削除権限を付与しない。

| アクション | 対象・条件 |
| --- | --- |
| s3:GetObject、s3:GetObjectVersion | バケットのprocessed/* |
| s3:ListBucket | バケット。prefixをprocessed、processed/、processed/*に限定 |
| s3:GetBucketLocation | バケット。prefix条件とは分けて設定 |

この読取専用の設計はSnowflake連携用ロールに対するもの。ローカルからS3へアップロードする認証主体とは別。

## 信頼ポリシーとRCP

AWSロールの信頼ポリシーは、IntegrationのDESCで得たSnowflake側IAMユーザーをPrincipalに指定し、ExternalIdの一致を条件にする。別環境で作成したIntegrationから得た値を使用し、現在のARNやExternalIdを汎用値として流用しない。

本環境では、信頼ポリシー設定後も組織のRCPによる組織外アクセス拒否が接続を妨げた。RCPを全体解除せず、以下の形で限定した例外を設けた。

1. 対象ロールを従来の組織外アクセス拒否文の対象から除外。
2. そのロールに対するsts操作は、指定したSnowflake IAMユーザー以外の組織外主体を条件付きで拒否。
3. AWSサービス経由の組織外ソースを拒否する元の文は保持。

保存済み本文はsql/aws/managed_account_resource_control_policy.json。2026-10-29に本人がAWSから提示したJSONと照合し、保存した変更案との内容一致を確認した。

RCPの例外はアクセス権の付与ではない。信頼ポリシーのPrincipal・ExternalId条件、ロールのS3権限、その他適用ポリシーも評価される。このRCPは組織ルートに適用されるため、別環境へ無条件にコピーする手順にはしない。

## S3アップロード時の認証

UbuntuのAWS CLIでブラウザー認証し、thelookプロファイルの一時認証情報を取得してDockerへ渡す。コンテナへ渡した認証情報はスナップショットであり、内部での自動更新は実装していない。

実際に確認した主体はAccountFullAccessRole。アップロード対象のraw・processedだけへ書込できる専用ロールへの絞込みは未実施。そのため、プロジェクト全体で完全な最小権限を達成済みとは説明しない。

## 実施した確認

- セカンダリロール無効で、ANALYSTからSTAGING、ETLからANALYTICSへの対象外スキーマ選択が拒否されることを確認。
- 両ロールから自分の対象スキーマを選択できることを確認。
- THELOOK_PIPELINE_USERで接続し、ETLロール・セカンダリロール無効・所定のWH/DB/スキーマを確認。
- IntegrationのREADとLISTの検証に成功。ETLロールでのLISTと全7ファイルのCOPYも成功。
- 保存済みRCPの内容を本人提示JSONと照合。

他の外部主体からの拒否、S3書込拒否、全組織ポリシーの包括的な監査は実際に試していない。接続成功だけで、あらゆる不正アクセスを防止したとの主張はしない。

## 再構築用ファイル

1. sql/snowflake_setup/01_roles_and_permissions.sql：ロール・WH・DB・スキーマ・権限。
2. sql/snowflake_setup/02_storage_integration.sql：AWSロール作成後のIntegration作成とDESC。
3. AWS側で信頼ポリシーと必要な組織ポリシーを環境に合わせて設定。
4. sql/snowflake_setup/03_external_stage.sql：Parquet形式と外部ステージ。
5. sql/ddl/create_tables.sql：ETLロールによるテーブル作成。
6. sql/snowflake_setup/04_pipeline_user.sql：専用ユーザーと公開鍵の登録手順。

既存環境は作成・接続済み。新規環境でこの一式を最初から実行する検証は未実施。IF NOT EXISTSは既存オブジェクトの定義や権限を期待値に更新・検証する仕組みではない。

## 公式資料

- [SnowflakeのS3 Storage Integration](https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration)
- [Snowflakeの鍵ペア認証](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [AWSのRCP構文](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_syntax.html)
