#!/usr/bin/env bash
# C.3 配对体细胞变异检测与过滤
# 从仓库根目录运行：bash scripts/02_somatic_variant_calling.sh
set -euo pipefail

ENV_FILE="${1:-config/analysis.env}"
[[ -f "$ENV_FILE" ]] || { echo "请先复制config/analysis.env.example为config/analysis.env并修改路径。" >&2; exit 1; }
source "$ENV_FILE"

mkdir -p "$VCF_DIR" "$FILTERED_VCF_DIR"
[[ -s "$PAIR_FILE" ]] || { echo "配对样本表不存在或为空：$PAIR_FILE" >&2; exit 1; }

# pairs.tsv列顺序：case_id、SWS_id、PV_id；SWS作为tumor，PV作为normal。
tail -n +2 "$PAIR_FILE" |
while IFS=$'\t' read -r CASE_ID SWS_ID PV_ID; do
    [[ -n "${CASE_ID:-}" ]] || continue
    TUMOR_ID="$SWS_ID"
    NORMAL_ID="$PV_ID"

    TUMOR_BAM="${BAM_DIR}/${TUMOR_ID}/sorted.bam"
    NORMAL_BAM="${BAM_DIR}/${NORMAL_ID}/sorted.bam"
    TUMOR_RG_BAM="${BAM_DIR}/${TUMOR_ID}/sorted_2.bam"
    NORMAL_RG_BAM="${BAM_DIR}/${NORMAL_ID}/sorted_2.bam"

    [[ -s "$TUMOR_BAM" ]] || { echo "缺少Tumor BAM: $TUMOR_BAM" >&2; exit 1; }
    [[ -s "$NORMAL_BAM" ]] || { echo "缺少Normal BAM: $NORMAL_BAM" >&2; exit 1; }

    # 1. 添加/替换Read Group并建立索引
    "$SAMTOOLS" addreplacerg -r "@RG\tID:${CASE_ID}_NORMAL\tSM:${NORMAL_ID}" \
      -o "$NORMAL_RG_BAM" "$NORMAL_BAM"
    "$SAMTOOLS" index "$NORMAL_RG_BAM"

    "$SAMTOOLS" addreplacerg -r "@RG\tID:${CASE_ID}_TUMOR\tSM:${TUMOR_ID}" \
      -o "$TUMOR_RG_BAM" "$TUMOR_BAM"
    "$SAMTOOLS" index "$TUMOR_RG_BAM"

    # 2. GATK Mutect2配对体细胞变异检测
    "$GATK" Mutect2 -R "$REFERENCE" \
      -I "$TUMOR_RG_BAM" -I "$NORMAL_RG_BAM" \
      --tumor-sample "$TUMOR_ID" --normal-sample "$NORMAL_ID" \
      -O "${VCF_DIR}/${CASE_ID}_somatic.vcf"

    # 3. GATK FilterMutectCalls变异过滤
    "$GATK" FilterMutectCalls -R "$REFERENCE" \
      -V "${VCF_DIR}/${CASE_ID}_somatic.vcf" \
      -O "${FILTERED_VCF_DIR}/${CASE_ID}_filtered.vcf"
done
