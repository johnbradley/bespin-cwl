#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
requirements:
  - class: ScatterFeatureRequirement
  - $import: ../types/bespin-types.yml
inputs:
  # NOTE: How long is this expected to take?
  # Intervals should come from capture kit in bed format
  intervals: File[]?
  # target intervals in picard interval_list format (created from intervals bed file)
  target_interval_list: File
  # bait intervals in picard interval_list format
  bait_interval_list: File
  interval_padding: int?
  # Read samples, fastq format
  # NOTE: Broad recommends the illumina basecalls and converts to unmapped SAM
  #   but do we typically have fastq?
  read_pair:
    type: ../types/bespin-types.yml#FASTQReadPairType
  # reference genome, fasta
  # NOTE: GATK can't handle compressed fasta reference genome
  # NOTE: is b37 appropriate to use?
  # NOTE: Indexed with bwa and avoided .64 files
  # NOTE: For mapping, they recommend a merge step, but this may only apply to having raw basecalls
  reference_genome: File
  # Number of threads to use for mapping
  threads: int
  # Read Group annotations
  # Can be the project name
  library: string
  # e.g. Illumina
  platform: string
  knownSites: File[] # vcf files of known sites, with indexing
  # Variant Recalibration - Common
  resource_dbsnp: File
outputs:
  fastqc_reports:
    type: File[]
    outputSource: qc/output_qc_report
  trim_reports:
    type: File[]
    outputSource: trim/trim_reports
  markduplicates_bam:
    type: File
    outputSource: mark_duplicates/output_dedup_bam_file
  # Recalibration
  recalibration_table:
    type: File
    outputSource: recalibrate_01_analyze/output_baseRecalibrator
  recalibrated_reads:
    type: File
    outputSource: recalibrate_02_apply_bqsr/calibrated_bam

steps:
  file_pair_details:
    run: ../tools/extract-named-file-pair-details.cwl
    in:
       read_pair: read_pair
       library: library
       platform: platform
    out:
       - reads
       - read_pair_name
       - read_group_header
  generate_sample_filenames:
    run: ../tools/generate-sample-filenames.cwl
    in:
      sample_name: file_pair_details/read_pair_name
    out:
      - combined_reads_output_filenames
      - mapped_reads_output_filename
      - sorted_reads_output_filename
      - dedup_reads_output_filename
      - dedup_metrics_output_filename
      - recal_reads_output_filename
      - recal_table_output_filename
      - raw_variants_output_filename
      - haplotypes_bam_output_filename
  combine_reads:
    run: ../tools/concat-gz-files.cwl
    scatter: [files, output_filename]
    scatterMethod: dotproduct
    in:
       files: file_pair_details/reads
       output_filename: generate_sample_filenames/combined_reads_output_filenames
    out:
       - output
  qc:
    run: ../tools/fastqc.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 4
        ramMin: 2500
    scatter: input_fastq_file
    in:
      input_fastq_file: combine_reads/output
      threads:
        default: 4
    out:
      - output_qc_report
  trim:
    run: ../tools/trim_galore.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 4
        ramMin: 8000
    in:
      reads: combine_reads/output
      paired:
        default: true
    out:
      - trimmed_reads
      - trim_reports
  map:
    run: ../tools/gitc-bwa-mem-samtools.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: $(inputs.threads)
        ramMin: 16000
        outdirMin: 12000
        tmpdirMin: 12000
    in:
      reads: trim/trimmed_reads
      reference: reference_genome
      read_group_header: file_pair_details/read_group_header
      output_filename: generate_sample_filenames/mapped_reads_output_filename
      threads: threads
    out:
      - output
  mark_duplicates: # I thought this needed to be sorted but apparently not?
    run: ../tools/GATK4-MarkDuplicates.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 1
        ramMin: 4000
        outdirMin: 12000
        tmpdirMin: 12000
    in:
      input_file: map/sortedoutput
      output_filename: generate_sample_filenames/dedup_reads_output_filename
      metrics_filename: generate_sample_filenames/dedup_metrics_output_filename
    out:
      - output_dedup_bam_file
      - output_metrics_file
  sort:
    run: ../tools/GATK4-SortSam.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 1
        ramMin: 4000
        outdirMin: 12000
        tmpdirMin: 12000
    in:
      input_file: mark_duplicates/output_dedup_bam_file
      output_filename: generate_sample_filenames/sorted_reads_output_filename
    out:
      - sorted
  fixtags:
    run: ../tools/GATK4-SetNmAndUqTags.cwl # what does this do?
    requirements:
      - class: ResourceRequirement
        coresMin: 1
        ramMin: 4000
        outdirMin: 12000
        tmpdirMin: 12000
    in:
      input_file: sort/sorted
      output_filename: generate_sample_filenames/fixed_tag_reads_output_filename # TODO: Allocate this
    out:
      - fixed_tags_bam
  # Now recalibrate
  recalibrate_01_analyze:
    run: ../tools/GATK4-BaseRecalibrator.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 8
        ramMin: 4096
    in:
      inputBam_BaseRecalibrator: fixtags/fixed_tags_bam
      intervals: intervals
      interval_padding: interval_padding
      knownSites: knownSites
      cpu_threads:
        default: 8
      outputfile_BaseRecalibrator: generate_sample_filenames/recal_table_output_filename
      reference: reference_genome
    out:
      - output_baseRecalibrator
  recalibrate_02_apply_bqsr:
    run: ../tools/GATK4-ApplyBQSR.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 8
        ramMin: 4096
    in:
      inputBam_applyBQSR: fixtags/fixed_tags_bam
      intervals: intervals
      recalibration_report: recalibrate_01_analyze/output_baseRecalibrator
      cpu_threads:
        default: 8
      outputfile_printReads: generate_sample_filenames/recal_reads_output_filename
      reference: reference_genome
    out:
      - calibrated_bam
