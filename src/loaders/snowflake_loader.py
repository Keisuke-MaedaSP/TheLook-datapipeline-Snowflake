import json
import os

import snowflake.connector
import argparse


def connect_to_snowflake(config_path: str):
    with open(config_path, encoding="utf-8") as f:
        config = json.load(f)

    return snowflake.connector.connect(
        **config,
        private_key_password=os.environ[
            "SNOWFLAKE_PRIVATE_KEY_PASSWORD"
        ],
        enable_server_session_keep_alive_auto_detection=True
    )


def load_from_sql(config_path: str, sql_path: str):
    completed = 0

    with open(sql_path, encoding="utf-8") as sql_file:
        with connect_to_snowflake(config_path) as conn:
            for number, cursor in enumerate(
                conn.execute_stream(sql_file, remove_comments=True),
                start=1
            ):
                with cursor:
                    print(
                        f"SQL {number}: query_id={cursor.sfqid}",
                        flush=True
                    )

                    columns = [
                        column[0].lower()
                        for column in cursor.description
                    ]

                    for row in cursor:
                        result = dict(zip(columns, row))
                        print(result, flush=True)

                        if result.get("status") in {
                            "LOAD_FAILED", "PARTIALLY_LOADED"
                        }:
                            raise RuntimeError(
                                f"取り込み失敗: {result}"
                            )

                completed += 1

    if completed == 0:
        raise ValueError("実行対象のSQLがありません")

    print(f"SQL実行完了: {completed}文", flush=True)
    return completed


def main():
    parser = argparse.ArgumentParser(
        description="SQLファイルを順次実行してSnowflakeへロードする"
    )
    parser.add_argument(
        "--config",
        default="/app/config/snowflake_config.json"
    )
    parser.add_argument(
        "--sql",
        default="/app/sql/copy_into/load_data.sql"
    )
    args = parser.parse_args()

    load_from_sql(args.config, args.sql)


if __name__ == "__main__":
    main()
