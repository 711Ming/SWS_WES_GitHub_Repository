#!/usr/bin/env bash
# C.4 ANNOVAR变异注释与候选变异筛选
# 从仓库根目录运行：bash scripts/03_annovar_annotation_filter.sh
set -euo pipefail

ENV_FILE="${1:-config/analysis.env}"
[[ -f "$ENV_FILE" ]] || { echo "请先复制config/analysis.env.example为config/analysis.env并修改路径。" >&2; exit 1; }
source "$ENV_FILE"

mkdir -p "$ANNOTATION_DIR" "$FILTERED_VARIANTS_DIR"
[[ -s "$PAIR_FILE" ]] || { echo "配对样本表不存在或为空：$PAIR_FILE" >&2; exit 1; }

# 筛选条件按用户提供的AWK命令保留。
# 正式使用前需核对multianno文件的第9列和第32列含义。
tail -n +2 "$PAIR_FILE" |
while IFS=$'\t' read -r CASE_ID SWS_ID PV_ID; do
    [[ -n "${CASE_ID:-}" ]] || continue
    INPUT_VCF="${FILTERED_VCF_DIR}/${CASE_ID}_filtered.vcf"
    OUT_PREFIX="${ANNOTATION_DIR}/${CASE_ID}"
    ANNOTATION_FILE="${OUT_PREFIX}.${ANNOVAR_BUILDVER}_multianno.txt"
    OUTPUT_VARIANTS="${FILTERED_VARIANTS_DIR}/${CASE_ID}_filtered_variants.txt"

    [[ -s "$INPUT_VCF" ]] || { echo "缺少过滤后VCF: $INPUT_VCF" >&2; exit 1; }

    # 1. ANNOVAR功能注释
    perl "$ANNOVAR" "$INPUT_VCF" "$ANNOVAR_DB" \
      -buildver "$ANNOVAR_BUILDVER" \
      -out "$OUT_PREFIX" -remove \
      -protocol "$ANNOVAR_PROTOCOL" \
      -operation "$ANNOVAR_OPERATION" \
      -nastring . -vcfinput

    [[ -s "$ANNOTATION_FILE" ]] || { echo "未找到注释结果：$ANNOTATION_FILE" >&2; exit 1; }

    # 2. 按原始AWK条件筛选
    awk -F'\t' \
      '$9 == "nonsynonymous SNV" && ($32 ~ /Pathogenic/ || $32 ~ /Likely_pathogenic/)' \
      "$ANNOTATION_FILE" > "$OUTPUT_VARIANTS"
done
