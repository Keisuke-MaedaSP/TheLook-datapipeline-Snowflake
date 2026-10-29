-- 自動実行用ユーザーの作成手順（既存環境では保存だけでよい）。
-- 01_roles_and_permissions.sqlの後、管理用ユーザーで実行する。
-- IF NOT EXISTSは既存ユーザーの設定を更新しない。
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS THELOOK_PIPELINE_USER
    TYPE = SERVICE
    DEFAULT_ROLE = THELOOK_ETL_ROLE
    DEFAULT_SECONDARY_ROLES = ()
    DEFAULT_WAREHOUSE = THELOOK_WH
    DEFAULT_NAMESPACE = 'THELOOK_DB.STAGING'
    COMMENT = 'TheLook pipeline key-pair authentication user';

GRANT ROLE THELOOK_ETL_ROLE TO USER THELOOK_PIPELINE_USER;

-- 新規環境で鍵を登録するときだけ、以下を編集して実行する。
-- rsa_key.pubのBEGIN/END行と改行を除いた公開鍵本文を指定する。
-- 秘密鍵（rsa_key.p8）やパスフレーズをこのファイルに記載しない。
-- 既存環境の公開鍵を不用意に上書きしないため、登録文はコメントにしている。
-- ALTER USER THELOOK_PIPELINE_USER
--     SET RSA_PUBLIC_KEY = '<PUBLIC_KEY_BODY>';

SHOW GRANTS TO USER THELOOK_PIPELINE_USER;
DESC USER THELOOK_PIPELINE_USER;

-- 参照：https://docs.snowflake.com/en/sql-reference/sql/create-user
-- 参照：https://docs.snowflake.com/en/user-guide/key-pair-auth
