#!/usr/bin/env python3
import json
import sys
import argparse

def main():
    parser = argparse.ArgumentParser(description="Automated Gatekeeper for Sequencing Quality")
    parser.add_argument("--json", required=True, help="Path to fastp.json file")
    parser.add_argument("--min_q30", type=float, default=80.0, help="Minimum acceptable percentage of Q30 bases")
    parser.add_argument("--min_reads", type=int, default=1000000, help="Minimum required total read count")
    parser.add_argument("--output", required=True, help="Path to write the status log")
    args = parser.parse_args()

    # 1. Parse JSON metadata
    with open(args.json, 'r') as f:
        qc_data = json.load(f)
    
    # Extract operational and technical metadata metrics
    total_reads = qc_data["summary"]["before_filtering"]["total_reads"]
    q30_rate = qc_data["summary"]["before_filtering"]["q30_rate"] * 100 # Convert to percentage

    # 2. Automated Validation Assertions
    passed = True
    reasons = []

    if q30_rate < args.min_q30:
        passed = False
        reasons.append(f"Low Quality: Q30 rate is {q30_rate:.2f}% (Threshold: >={args.min_q30}%)")
    
    if total_reads < args.min_reads:
        passed = False
        reasons.append(f"Low Yield: Total reads count is {total_reads} (Threshold: >={args.min_reads})")

    # 3. Decision Reporting
    with open(args.output, "w") as out:
        if passed:
            out.write(f"STATUS: PASS\nTotal Reads: {total_reads}\nQ30 Rate: {q30_rate:.2f}%\n")
            print(f"[QC PASS] Metrics are clean.", file=sys.stderr)
        else:
            out.write(f"STATUS: FAIL\nReasons: {', '.join(reasons)}\n")
            print(f"[QC FAIL] Automatically Quarantined Sample due to: {reasons}", file=sys.stderr)
            # Exit with code 1 to intentionally halt Snakemake if validation fails
            sys.exit(1)

if __name__ == "__main__":
    main()

