#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import json
import tempfile

def main():
    repo_root = "/Users/perkunas/jail/digital-pipeline-repo"
    benchmark_path = os.path.join(repo_root, "benchmark_results.jsonl")
    app_flutter_dir = os.path.join(repo_root, "app_flutter")
    
    # 1. Truncate/clear the benchmark results file before the run
    if os.path.exists(benchmark_path):
        os.remove(benchmark_path)
    
    print("Running integration tests...")
    # Run the test command
    cmd = ["flutter", "test", "integration_test/node_iteration_test.dart", "-d", "macos"]
    result = subprocess.run(cmd, cwd=app_flutter_dir, capture_output=True, text=True)
    
    test_failed = (result.returncode != 0)
    stdout = result.stdout
    stderr = result.stderr
    
    print("Test run completed. Exit code:", result.returncode)
    
    # 2. Parse benchmark_results.jsonl
    passes = []
    if os.path.exists(benchmark_path):
        with open(benchmark_path, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        passes.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
                        
    # 3. Analyze results
    rss_threshold_kb = 100 * 1024 # 100MB in KB
    jank_threshold_ms = 16.6
    
    regression_reasons = []
    
    if test_failed:
        regression_reasons.append("Integration test execution failed (non-zero exit code or assertion failure).")
        
    max_memory_delta_kb = 0
    max_avg_frame_build_time = 0.0
    leak_detected_any = False
    leak_details_all = []
    
    for idx, p in enumerate(passes):
        passed_val = p.get("passed", True)
        if not passed_val:
            regression_reasons.append(f"Pass {idx} was marked as failed.")
            
        mem_delta = p.get("memory_delta_kb", 0)
        if mem_delta > max_memory_delta_kb:
            max_memory_delta_kb = mem_delta
            
        avg_build_time = p.get("average_frame_build_time_ms", 0.0)
        if avg_build_time > max_avg_frame_build_time:
            max_avg_frame_build_time = avg_build_time
            
        leak_detected = p.get("leak_detected", False)
        if leak_detected:
            leak_detected_any = True
            details = p.get("leak_details", "")
            if details:
                leak_details_all.append(f"Pass {idx}: {details}")
                
    if max_memory_delta_kb > rss_threshold_kb:
        regression_reasons.append(f"Memory growth delta of {max_memory_delta_kb / 1024:.2f}MB exceeded the 100MB threshold.")
        
    if max_avg_frame_build_time > jank_threshold_ms:
        regression_reasons.append(f"Average frame build time of {max_avg_frame_build_time:.2f}ms exceeded the 16.6ms jank threshold.")
        
    if leak_detected_any:
        regression_reasons.append("Memory leak was detected during the run.")

    # Print a summary of findings to console
    print("\n--- Profile Audit Summary ---")
    print(f"Total passes executed: {len(passes)}")
    print(f"Max single-pass memory growth: {max_memory_delta_kb / 1024:.2f} MB")
    print(f"Max average frame build time: {max_avg_frame_build_time:.2f} ms")
    print(f"Memory leak detected: {leak_detected_any}")
    if leak_details_all:
        print("Leak Details:")
        for d in leak_details_all:
            print(" -", d)
    print("-----------------------------\n")
    
    # 4. If defect detected, file a GitHub issue
    if regression_reasons:
        print("Defect or regression detected! Preparing report...")
        
        # Format issue body
        report_lines = [
            "# Performance & Memory Profile Regression Report",
            "",
            "An automated performance audit run has detected regressions or failures.",
            "",
            "## Summary of Failures / Regressions",
            *[f"- {reason}" for reason in regression_reasons],
            "",
            "## Key Metrics",
            f"- **Max Pass Memory Delta**: {max_memory_delta_kb / 1024:.2f} MB",
            f"- **Max Avg Frame Build Time**: {max_avg_frame_build_time:.2f} ms (Target: <16.6ms)",
            f"- **Memory Leak Detected**: {leak_detected_any}",
            "",
            "## Pass Details",
            "| Pass | Theme | Text Scale | Memory Delta (MB) | Avg Frame Build Time (ms) | Worst Frame Build Time (ms) | Passed | Leak Detected |",
            "| --- | --- | --- | --- | --- | --- | --- | --- |"
        ]
        
        for p in passes:
            pass_num = p.get("pass_count", "?")
            theme = p.get("theme_mode", "?")
            scale = p.get("text_scale", "?")
            m_delta = p.get("memory_delta_kb", 0) / 1024.0
            avg_bt = p.get("average_frame_build_time_ms", 0.0)
            worst_bt = p.get("worst_frame_build_time_ms", 0.0)
            passed_bool = p.get("passed", True)
            leak_bool = p.get("leak_detected", False)
            
            report_lines.append(
                f"| {pass_num} | {theme} | {scale} | {m_delta:.2f} MB | {avg_bt:.2f} ms | {worst_bt:.2f} ms | {passed_bool} | {leak_bool} |"
            )
            
        if leak_details_all:
            report_lines.extend([
                "",
                "## Leak Analysis Details",
                *[f"- {d}" for d in leak_details_all]
            ])
            
        report_lines.extend([
            "",
            "## Test Run Output (Stderr / Failures)",
            "```",
            stderr[-4000:] if stderr else "No stderr output recorded.",
            "```",
            "",
            "## Test Run Output (Stdout Truncated)",
            "```",
            stdout[-4000:] if stdout else "No stdout output recorded.",
            "```"
        ])
        
        report_body = "\n".join(report_lines)
        
        # Write report to temp file
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as temp_file:
            temp_file.write(report_body)
            temp_file_path = temp_file.name
            
        try:
            print("Filing GitHub issue...")
            gh_cmd = [
                "gh", "issue", "create",
                "--title", "Defect: Performance or Memory Regression detected by Profiler",
                "--body-file", temp_file_path,
                "--label", "bug"
            ]
            gh_result = subprocess.run(gh_cmd, capture_output=True, text=True)
            if gh_result.returncode == 0:
                issue_url = gh_result.stdout.strip()
                print("GitHub issue created successfully!")
                print("Issue URL/ID:", issue_url)
            else:
                print("Failed to create GitHub issue via CLI:")
                print(gh_result.stderr)
        finally:
            # Clean up the temp file
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)
                
        sys.exit(1)
    else:
        print("Performance and memory profile audit passed successfully!")
        sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run Flutter integration tests and audit performance/memory profiles. "
                    "Files a GitHub issue if regressions are detected."
    )
    parser.parse_args()
    main()
