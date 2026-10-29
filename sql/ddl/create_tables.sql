-- 全7テーブルのDDL。初期ロール・DB・Schema設定の後に実行する。
-- IF NOT EXISTSは既存テーブルを維持する。既存定義の変更・照合は行わない。
-- 主キー候補と参照整合性は品質SQLで確認し、元データのNULL・不一致は保持する。

USE ROLE THELOOK_ETL_ROLE;
USE SECONDARY ROLES NONE;

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.DISTRIBUTION_CENTERS (
  id         NUMBER(38,0),
  name       VARCHAR,
  latitude   FLOAT,
  longitude  FLOAT
);

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.PRODUCTS (
  id                      NUMBER(38,0),
  cost                    FLOAT,
  category                VARCHAR,
  name                    VARCHAR,
  brand                   VARCHAR,
  retail_price            FLOAT,
  department              VARCHAR,
  sku                     VARCHAR,
  distribution_center_id  NUMBER(38,0)
);

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.INVENTORY_ITEMS (
  id                              NUMBER(38,0),
  product_id                      NUMBER(38,0),
  created_at                      TIMESTAMP_LTZ(6),
  sold_at                         TIMESTAMP_LTZ(6),
  cost                            FLOAT,
  product_category                VARCHAR,
  product_name                    VARCHAR,
  product_brand                   VARCHAR,
  product_retail_price            FLOAT,
  product_department              VARCHAR,
  product_sku                     VARCHAR,
  product_distribution_center_id  NUMBER(38,0)
);

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.ORDERS (
  order_id      NUMBER(38,0),
  user_id       NUMBER(38,0),
  status        VARCHAR,
  gender        VARCHAR,
  created_at    TIMESTAMP_LTZ(6),
  returned_at   TIMESTAMP_LTZ(6),
  shipped_at    TIMESTAMP_LTZ(6),
  delivered_at  TIMESTAMP_LTZ(6),
  num_of_item   NUMBER(38,0)
);

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.ORDER_ITEMS (
  id                 NUMBER(38,0),
  order_id           NUMBER(38,0),
  user_id            NUMBER(38,0),
  product_id         NUMBER(38,0),
  inventory_item_id  NUMBER(38,0),
  status             VARCHAR,
  created_at         TIMESTAMP_LTZ(6),
  shipped_at         TIMESTAMP_LTZ(6),
  delivered_at       TIMESTAMP_LTZ(6),
  returned_at        TIMESTAMP_LTZ(6),
  sale_price         FLOAT
);

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.USERS (
  id              NUMBER(38,0),
  first_name      VARCHAR,
  last_name       VARCHAR,
  email           VARCHAR,
  age             NUMBER(38,0),
  gender          VARCHAR,
  state           VARCHAR,
  street_address  VARCHAR,
  postal_code     VARCHAR,
  city            VARCHAR,
  country         VARCHAR,
  latitude        FLOAT,
  longitude       FLOAT,
  traffic_source  VARCHAR,
  created_at      TIMESTAMP_LTZ(6)
);

CREATE TABLE IF NOT EXISTS THELOOK_DB.STAGING.EVENTS (
  id               NUMBER(38,0),
  user_id          NUMBER(38,0),
  sequence_number  NUMBER(38,0),
  session_id       VARCHAR,
  created_at       TIMESTAMP_LTZ(6),
  ip_address       VARCHAR,
  city             VARCHAR,
  state            VARCHAR,
  postal_code      VARCHAR,
  browser          VARCHAR,
  traffic_source   VARCHAR,
  uri              VARCHAR,
  event_type       VARCHAR
);
