#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
requirements:
- class: SubworkflowFeatureRequirement
label: qiime2
inputs:
  sequences_directory: Directory
  artifact_type: string
  artifact_filename: string
  barcodes_file: File
  barcodes_column: string
  per_sample_sequences_filename: string
  demux_visualization_filename: string
  dada2_trim_left: int
  dada2_trunc_len: int
  dada2_representative_sequences_filename: string
  dada2_table_filename: string
  dada2_denoising_stats_filename: string
  dada2_stats_filename: string
  feature_table_summary_filename: string
  feature_table_tabulation_filename: string
  aligned_rep_seqs_filename: string
  masked_aligned_rep_seqs_filename: string
  unrooted_tree_filename: string
  rooted_tree_filename: string
outputs:
  sequences_artifact:
    type: File
    outputSource: import_sequences/sequences_artifact
  demux_sequences_artifact:
    type: File
    outputSource: demux_sequences/demux_sequences_artifact
  demux_visualization_artifact:
    type: File
    outputSource: demux_visualization/demux_visualization_artifact
  dada2_representative_sequences:
    type: File
    outputSource: dada2_denoise_single/representative_sequences
  dada2_table:
    type: File
    outputSource: dada2_denoise_single/table
  dada2_representative_sequences:
    type: File
    outputSource: dada2_denoise_single/representative_sequences
  dada2_visualization_artifact:
    type: File
    outputSource: dada2_visualization/visualization_artifact
  feature_table_summarize_visualization:
    type: File
    outputSource: feature_table_summarize/visualization
  feature_table_tabulation_visualization:
    type: File
    outputSource: feature_table_tabulation/visualization
  aligned_representative_sequences:
    type: File
    outputSource: align_representative_sequences/alignment
  masked_representative_sequences:
    type: File
    outputSource: mask_representative_sequences/masked_aligned_rep_seqs
  unrooted_tree:
    type: File
    outputSource: create_tree_from_alignment/unrooted_tree
  rooted_tree:
    type: File
    outputSource: root_tree/rooted_tree
steps:
  import_sequences:
    run: ../tools/qiime-tools-import.cwl
    in:
      input_path: sequences_directory
      type: artifact_type
      output_filename: artifact_filename
    out:
      - sequences_artifact
  demux_sequences:
    run: ../tools/qiime-demux-emp-single.cwl
    in:
      seqs: import_sequences/sequences_artifact
      barcodes_file: barcodes_file
      barcodes_column: barcodes_column
      per_sample_sequences_filename: per_sample_sequences_filename
    out:
      - demux_sequences_artifact
  demux_visualization:
    run: ../tools/qiime-demux-summarize.cwl
    in:
      data: demux_sequences/demux_sequences_artifact
      visualization_filename: demux_visualization_filename
    out:
      - demux_visualization_artifact
  dada2_denoise_single:
    run: ../tools/qiime-dada2-denoise-single.cwl
    in:
      demultiplexed_seqs: demux_sequences/demux_sequences_artifact
      trim_left: dada2_trim_left
      trunc_len: dada2_trunc_len
      representative_sequences_filename: dada2_representative_sequences_filename
      table_filename: dada2_table_filename
      denoising_stats_filename: dada2_denoising_stats_filename
    out:
      - representative_sequences
      - table
      - denoising_stats
  dada2_visualization:
    run: ../tools/qiime-metadata-tabulate.cwl
    in:
      input_file: dada2_denoise_single/denoising_stats
      visualization_filename: dada2_stats_filename
    out:
      - visualization_artifact
  feature_table_summarize:
    run: ../tools/qiime-feature-table-summarize.cwl
    in:
      table: dada2_denoise_single/table
      visualization_filename: feature_table_summary_filename
      sample_metadata_file: barcodes_file
    out:
      - visualization
  feature_table_tabulation:
    run: ../tools/qiime-feature-table-tabulate-seqs.cwl
    in:
      data: dada2_denoise_single/representative_sequences
      visualization_filename: feature_table_tabulation_filename
    out:
      - visualization
  align_representative_sequences:
    run: ../tools/qiime-alignment-mafft.cwl
    in:
      sequences: dada2_denoise_single/representative_sequences
      alignment_filename: aligned_rep_seqs_filename
    out:
      - alignment
  mask_representative_sequences:
    run: ../tools/qiime-alignment-mask.cwl
    in:
      alignment: align_representative_sequences/alignment
      masked_aligned_rep_seqs_filename: masked_aligned_rep_seqs_filename
    out:
      - masked_aligned_rep_seqs
  create_tree_from_alignment:
    run: ../tools/qiime-phylogeny-fasttree.cwl
    in:
      alignment: mask_representative_sequences/masked_aligned_rep_seqs
      tree_filename: unrooted_tree_filename
    out:
      - unrooted_tree
  root_tree:
    run: ../tools/qiime-phylogeny-midpoint-root.cwl
    in:
      tree: create_tree_from_alignment/unrooted_tree
      rooted_tree_filename: rooted_tree_filename
    out:
      - rooted_tree