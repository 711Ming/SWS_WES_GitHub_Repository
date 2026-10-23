# SWS-WES analysis workflow

本仓库按C.1–C.4整理现有WES分析代码，并将具体病人样本标识和服务器绝对路径替换为可修改占位符。

## 目录结构

```text
SWS_WES_GitHub_Repository/
├── README.md
├── .gitignore
├── config/
│   ├── config.yaml.example
│   ├── pairs.tsv.example
│   └── analysis.env.example
├── Snakefile
└── scripts/
    ├── 02_somatic_variant_calling.sh
    └── 03_annovar_annotation_filter.sh
```

## C.1 配置

复制示例文件并填写实际路径：

```bash
cp config/config.yaml.example config.yaml
cp config/analysis.env.example config/analysis.env
cp config/pairs.tsv.example config/pairs.tsv
```

`config.yaml`用于FASTQ输入、软件路径、参考基因组和预处理结果目录。`config/analysis.env`供C.3和C.4脚本共用。`pairs.tsv`列顺序为`case_id`、`SWS_id`、`PV_id`，列之间为制表符。SWS为病灶组织（Mutect2 tumor），PV为配对外周血（Mutect2 normal）。

## C.2 FASTQ预处理与参考基因组比对

需要安装Trimmomatic、BWA、Samtools及Snakemake，并按实际环境准备参考基因组及其索引。原始代码中的Trimmomatic参数保留为：

- `ILLUMINACLIP:TruSeq3-PE.fa:2:30:10`
- `SLIDINGWINDOW:4:20`
- `MINLEN:50`

先进行计划检查：

```bash
snakemake --snakefile Snakefile --configfile config.yaml --cores 8 --dry-run
```

确认路径和样本无误后运行：

```bash
snakemake --snakefile Snakefile --configfile config.yaml --cores 8 --printshellcmds
```

输出BAM路径为`<results_dir>/bam/<sample_id>/sorted.bam`。因此，`config/analysis.env`中的`BAM_DIR`应设为`<results_dir>/bam`。

## C.3 配对体细胞变异检测与过滤

运行：

```bash
bash scripts/02_somatic_variant_calling.sh
```

脚本按配对表执行Samtools `addreplacerg`及`index`，随后运行GATK Mutect2和FilterMutectCalls。输出文件为`<case_id>_somatic.vcf`及`<case_id>_filtered.vcf`。

请确保BAM中的SM名称与配对表中的样本ID一致。

## C.4 ANNOVAR注释与候选变异筛选

运行：

```bash
bash scripts/03_annovar_annotation_filter.sh
```

使用的注释设置按提供命令保留：`hg19`、`refGene`、`gnomad211_exome`、`clinvar_20220320`，操作类型为`g,f,f`。请确认本地ANNOVAR数据库名称与版本。

AWK筛选条件按原始命令保留：

```bash
awk -F'\t' \
  '$9 == "nonsynonymous SNV" && ($32 ~ /Pathogenic/ || $32 ~ /Likely_pathogenic/)' \
  input.hg19_multianno.txt > filtered_variants.txt
```

**重要：**运行前必须查看实际`multianno.txt`表头，核实第9列和第32列的含义。ANNOVAR输出前缀已统一为病例ID，以避免原命令中`-out patient2`与后续读取`WXS.hg19_multianno.txt`不一致的问题。

## 软件与版本

现有材料指向Trimmomatic v0.39、GATK v4.6.0.0、GRCh37参考基因组和ANNOVAR `hg19`注释版本。BWA、Samtools、Snakemake及ANNOVAR数据库的实际版本需根据运行环境记录。

## 可重复性与数据保护说明

- 本仓库没有加入现有材料未能证实执行的FastQC/MultiQC、MarkDuplicates、BQSR或覆盖度统计步骤。
- 本仓库不包含FASTQ、BAM、VCF、参考基因组或ANNOVAR数据库。
- 不建议将人类测序数据或包含真实个人路径、样本标识的配置文件提交至公开GitHub仓库。
- ClinVar中的Pathogenic/Likely_pathogenic分类不能单独证明变异是SWS的致病性体细胞变异；应结合配对样本证据、测序质量及后续验证。
