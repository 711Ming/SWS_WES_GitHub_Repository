# C.2 FASTQ预处理及参考基因组比对
# 仅包含原始代码中可确认的Trimmomatic、BWA-MEM、Samtools sort/index。

configfile: "config.yaml"

REFERENCE = config["reference"]
BWA = config["bwa"]
TRIMMOMATIC = config["trimmomatic"]
ADAPTERS = config["adapters"]
SAMTOOLS = config["samtools"]
RESULTS_DIR = config["results_dir"].rstrip("/")
SAMPLES = config["samples"]

rule all:
    input:
        expand(RESULTS_DIR + "/bam/{sample}/sorted.bam.bai", sample=SAMPLES.keys())

rule trimmomatic:
    input:
        P1=lambda wc: SAMPLES[wc.sample]["R1"],
        P2=lambda wc: SAMPLES[wc.sample]["R2"]
    output:
        trimmed_R1=f"{RESULTS_DIR}/{{sample}}/trimmed_R1.fastq.gz",
        unpaired_R1=f"{RESULTS_DIR}/{{sample}}/unpaired_R1.fastq.gz",
        trimmed_R2=f"{RESULTS_DIR}/{{sample}}/trimmed_R2.fastq.gz",
        unpaired_R2=f"{RESULTS_DIR}/{{sample}}/unpaired_R2.fastq.gz"
    threads: 8
    shell:
        r"""
        set -euo pipefail
        mkdir -p "{RESULTS_DIR}/{wildcards.sample}"
        java -jar "{TRIMMOMATIC}" PE -threads {threads} \
          "{input.P1}" "{input.P2}" \
          "{output.trimmed_R1}" "{output.unpaired_R1}" \
          "{output.trimmed_R2}" "{output.unpaired_R2}" \
          ILLUMINACLIP:"{ADAPTERS}":2:30:10 \
          SLIDINGWINDOW:4:20 MINLEN:50
        """

rule align:
    input:
        R1=f"{RESULTS_DIR}/{{sample}}/trimmed_R1.fastq.gz",
        R2=f"{RESULTS_DIR}/{{sample}}/trimmed_R2.fastq.gz"
    output:
        bam=f"{RESULTS_DIR}/bam/{{sample}}/sorted.bam",
        bai=f"{RESULTS_DIR}/bam/{{sample}}/sorted.bam.bai"
    threads: 8
    shell:
        r"""
        set -euo pipefail
        mkdir -p "{RESULTS_DIR}/bam/{wildcards.sample}"
        "{BWA}" mem -t {threads} "{REFERENCE}" "{input.R1}" "{input.R2}" |
          "{SAMTOOLS}" sort -@ {threads} -o "{output.bam}" -
        "{SAMTOOLS}" index "{output.bam}" "{output.bai}"
        """
