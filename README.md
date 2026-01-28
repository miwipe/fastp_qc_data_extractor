# fastp_qc_data_extractor
A lightweight command-line tool to extract common fastp QC metrics from per-sample HTML reports and consolidate them into an analysis-ready, tab-separated (TSV) table.

## About 

Bash-based extractor for `fastp` HTML QC reports that outputs a per-sample TSV summary, including sequencing mode, duplication rate, total reads (pre and post filtering with K/M normalization), GC content, insert size peak, and filtering breakdown.

## Usage
1) Clone the repository
```
git clone https://github.com/miwipe/fastp_qc_data_extractor.git
```
2) Enter the repository directory
```
cd fastp_qc_data_extractor/bin/
```
3) Make the script executable
```
chmod +x extract_fastp_qc.sh
```
4) Run on a directory of `fastp` HTML reports
```
./extract_fastp_qc.sh /path/to/fastp_reports/ > fastp_qc_summary.tsv
```
5) Or run on specific files (or a glob)
```
./extract_fastp_qc.sh /path/to/fastp_reports/*.html > fastp_qc_summary.tsv
```
Inspect the output
```
head -n 5 fastp_qc_summary.tsv | column -t -s $'\t'
```
