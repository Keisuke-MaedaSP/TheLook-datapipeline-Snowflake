import json
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import cleaning_data as cl
from pathlib import Path
import argparse


def process_table_to_parquet(input_csv: str, output_parquet: str, table_name: str, config_path: str, chunk_size: int = 10000):
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    rules = config[table_name]
    csv_dtypes = {
        "users": {
            "postal_code": "string"
        },
        "events": {
            "postal_code": "string",
            "user_id": "Int64"
        }
    }
    output_path = Path(output_parquet)
    temp_path = output_path.with_suffix(output_path.suffix + ".part")

    total = 0
    schema = None
    writer = None

    try:
        with pd.read_csv(
            input_csv,
            chunksize=chunk_size,
            dtype=csv_dtypes.get(table_name)
        ) as reader:
            for df in reader:
                df = cl.to_datetime(df, rules.get("to_datetime", []))
                df = cl.to_lowercase(df, rules.get("to_lowercase", []))
                df = cl.to_hash(df, rules.get("to_hash", []))

                table = pa.Table.from_pandas(
                    df,
                    schema=schema,
                    preserve_index=False
                )

                if writer is None:
                    schema = table.schema
                    writer = pq.ParquetWriter(
                        str(temp_path),
                        schema,
                        compression="snappy"
                    )

                writer.write_table(table)
                total += table.num_rows
                print(f"書き込んだ行数: {table.num_rows} / 累計: {total}")

    finally:
        if writer is not None:
            writer.close()

    if writer is None:
        print("データが0行のため、保存しませんでした")
        return

    temp_path.replace(output_path)
    print(f"保存完了: {output_path} / 合計行数: {total}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="CSVをチャンク加工してParquetへ保存する"
    )
    parser.add_argument("--table", required=True)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--config", default="/app/config/column_config.json")
    parser.add_argument("--chunk-size", type=int, default=10000)
    args = parser.parse_args()

    process_table_to_parquet(
        input_csv=args.input,
        output_parquet=args.output,
        table_name=args.table,
        config_path=args.config,
        chunk_size=args.chunk_size
    )
