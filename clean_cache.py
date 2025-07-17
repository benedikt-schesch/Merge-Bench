#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cache cleaning utility for Merge-Bench API cache."""

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

from loguru import logger

CACHE_DIR = Path("query_cache")


class CacheAnalyzer:
    """Analyzes and cleans API cache entries."""

    def __init__(self) -> None:
        self.cache_stats: Dict[str, Dict[str, Any]] = {}
        self.problematic_entries: List[Dict[str, Any]] = []
        self.total_entries: int = 0

    def scan_cache(self) -> Dict[str, Dict[str, int]]:
        """Scan cache directory and analyze entries."""
        logger.info("Scanning cache directory...")

        if not CACHE_DIR.exists():
            logger.warning(f"Cache directory {CACHE_DIR} does not exist")
            return {}

        self.cache_stats = {}
        self.problematic_entries = []
        self.total_entries = 0

        # Walk through all model directories
        for model_dir in CACHE_DIR.iterdir():
            if not model_dir.is_dir():
                continue

            model_name = str(model_dir.relative_to(CACHE_DIR))
            self.cache_stats[model_name] = {
                "total": 0,
                "empty_results": 0,
                "malformed_json": 0,
                "valid": 0,
                "files": [],
            }

            # Check each cache file in the model directory
            for cache_file in model_dir.glob("**/*.json"):
                self.total_entries += 1
                self.cache_stats[model_name]["total"] += 1
                self.cache_stats[model_name]["files"].append(cache_file)

                try:
                    with open(cache_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    # Check if result is empty or problematic
                    result = data.get("result", "")
                    if not result or not result.strip():
                        self.cache_stats[model_name]["empty_results"] += 1
                        self.problematic_entries.append(
                            {
                                "file": cache_file,
                                "model": model_name,
                                "issue": "empty_result",
                                "data": data,
                            }
                        )
                    else:
                        self.cache_stats[model_name]["valid"] += 1

                except json.JSONDecodeError:
                    self.cache_stats[model_name]["malformed_json"] += 1
                    self.problematic_entries.append(
                        {
                            "file": cache_file,
                            "model": model_name,
                            "issue": "malformed_json",
                            "data": None,
                        }
                    )
                except Exception as e:
                    logger.error(f"Error reading {cache_file}: {e}")

        return self.cache_stats

    def print_statistics(self) -> None:
        """Print detailed cache statistics."""
        print("\n" + "=" * 60)
        print("📊 CACHE ANALYSIS REPORT")
        print("=" * 60)

        if not self.cache_stats:
            print("❌ No cache entries found")
            return

        total_problematic = len(self.problematic_entries)
        total_valid = sum(stats["valid"] for stats in self.cache_stats.values())

        print("📈 SUMMARY:")
        print(f"  Total entries: {self.total_entries}")
        print(f"  Valid entries: {total_valid}")
        print(f"  Problematic entries: {total_problematic}")

        print("\n📋 BY MODEL:")
        for model_name, stats in sorted(self.cache_stats.items()):
            print(f"\n  🤖 {model_name}")
            print(f"     Total entries: {stats['total']}")
            print(f"     Valid entries: {stats['valid']}")
            if stats["empty_results"] > 0:
                print(f"     ❌ Empty results: {stats['empty_results']}")
            if stats["malformed_json"] > 0:
                print(f"     ❌ Malformed JSON: {stats['malformed_json']}")

        if total_problematic > 0:
            print("\n⚠️  PROBLEMATIC ENTRIES FOUND:")
            for entry in self.problematic_entries[:5]:  # Show first 5
                issue_emoji = "📄" if entry["issue"] == "empty_result" else "💥"
                print(
                    f"     {issue_emoji} {entry['model']}: {entry['file'].name} ({entry['issue']})"
                )
            if len(self.problematic_entries) > 5:
                print(f"     ... and {len(self.problematic_entries) - 5} more")

        print("=" * 60)

    def clean_empty_results(self, dry_run: bool = False) -> int:
        """Clean cache entries with empty results."""
        empty_entries = [
            e for e in self.problematic_entries if e["issue"] == "empty_result"
        ]

        if not empty_entries:
            print("✅ No empty result entries found to clean")
            return 0

        print(
            f"\n🧹 {'[DRY RUN] ' if dry_run else ''}Cleaning {len(empty_entries)} "
            "empty result entries..."
        )

        if not dry_run and not self._confirm_action(
            f"Delete {len(empty_entries)} empty result entries"
        ):
            print("❌ Operation cancelled")
            return 0

        deleted_count = 0
        for entry in empty_entries:
            try:
                if dry_run:
                    print(f"  Would delete: {entry['file']}")
                else:
                    entry["file"].unlink()
                    print(f"  ✅ Deleted: {entry['file']}")
                deleted_count += 1
            except Exception as e:
                print(f"  ❌ Failed to delete {entry['file']}: {e}")

        if not dry_run:
            print(f"✅ Successfully cleaned {deleted_count} empty result entries")
        return deleted_count

    def clean_malformed_json(self, dry_run: bool = False) -> int:
        """Clean cache entries with malformed JSON."""
        malformed_entries = [
            e for e in self.problematic_entries if e["issue"] == "malformed_json"
        ]

        if not malformed_entries:
            print("✅ No malformed JSON entries found to clean")
            return 0

        print(
            f"\n🧹 {'[DRY RUN] ' if dry_run else ''}Cleaning {len(malformed_entries)} "
            "malformed JSON entries..."
        )

        if not dry_run and not self._confirm_action(
            f"Delete {len(malformed_entries)} malformed JSON entries"
        ):
            print("❌ Operation cancelled")
            return 0

        deleted_count = 0
        for entry in malformed_entries:
            try:
                if dry_run:
                    print(f"  Would delete: {entry['file']}")
                else:
                    entry["file"].unlink()
                    print(f"  ✅ Deleted: {entry['file']}")
                deleted_count += 1
            except Exception as e:
                print(f"  ❌ Failed to delete {entry['file']}: {e}")

        if not dry_run:
            print(f"✅ Successfully cleaned {deleted_count} malformed JSON entries")
        return deleted_count

    def clean_model_cache(self, model_name: str, dry_run: bool = False) -> int:
        """Clean all cache entries for a specific model."""
        if model_name not in self.cache_stats:
            print(f"❌ Model '{model_name}' not found in cache")
            return 0

        model_stats = self.cache_stats[model_name]
        total_entries = model_stats["total"]

        print(
            f"\n🧹 {'[DRY RUN] ' if dry_run else ''}Cleaning all {total_entries} "
            f"entries for model '{model_name}'..."
        )

        if not dry_run and not self._confirm_action(
            f"Delete ALL {total_entries} entries for model '{model_name}'"
        ):
            print("❌ Operation cancelled")
            return 0

        deleted_count = 0
        for cache_file in model_stats["files"]:
            try:
                if dry_run:
                    print(f"  Would delete: {cache_file}")
                else:
                    cache_file.unlink()
                    print(f"  ✅ Deleted: {cache_file}")
                deleted_count += 1
            except Exception as e:
                print(f"  ❌ Failed to delete {cache_file}: {e}")

        # Remove empty model directory
        if not dry_run and deleted_count > 0:
            try:
                model_dir = CACHE_DIR / model_name
                if model_dir.exists() and not any(model_dir.iterdir()):
                    model_dir.rmdir()
                    print(f"  ✅ Removed empty directory: {model_dir}")
            except Exception as e:
                logger.warning(
                    f"Could not remove directory {CACHE_DIR / model_name}: {e}"
                )

        if not dry_run:
            print(
                f"✅ Successfully cleaned {deleted_count} entries for model '{model_name}'"
            )
        return deleted_count

    def clean_all_cache(self, dry_run: bool = False) -> int:
        """Clean the entire cache."""
        if self.total_entries == 0:
            print("✅ Cache is already empty")
            return 0

        print(
            f"\n🧹 {'[DRY RUN] ' if dry_run else ''}Cleaning ENTIRE cache "
            f"({self.total_entries} entries)..."
        )

        if not dry_run and not self._confirm_action(
            f"Delete ALL {self.total_entries} cache entries"
        ):
            print("❌ Operation cancelled")
            return 0

        if dry_run:
            print(f"  Would delete entire cache directory: {CACHE_DIR}")
            return self.total_entries
        try:
            shutil.rmtree(CACHE_DIR)
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            print(
                f"✅ Successfully cleaned entire cache ({self.total_entries} entries)"
            )
            return self.total_entries
        except Exception as e:
            print(f"❌ Failed to clean cache: {e}")
            return 0

    def backup_cache(self, backup_dir: Optional[str] = None) -> bool:
        """Create a backup of the cache."""
        if backup_dir is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_dir = f"cache_backup_{timestamp}"

        backup_path = Path(backup_dir)

        try:
            print(f"📦 Creating cache backup at: {backup_path}")
            shutil.copytree(CACHE_DIR, backup_path)
            print("✅ Cache backup created successfully")
            return True
        except Exception as e:
            print(f"❌ Failed to create backup: {e}")
            return False

    def _confirm_action(self, message: str) -> bool:
        """Get user confirmation for destructive actions."""
        response = input(f"\n⚠️  {message}? (y/N): ").strip().lower()
        return response in ["y", "yes"]


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Clean and analyze Merge-Bench API cache",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python clean_cache.py                          # Show statistics only
  python clean_cache.py --clean-empty           # Clean empty results
  python clean_cache.py --clean-empty --dry-run # Preview what would be cleaned
  python clean_cache.py --clean-model "anthropic/claude-3.5-sonnet"
  python clean_cache.py --clean-all --backup    # Backup then clean everything
        """,
    )

    parser.add_argument(
        "--stats",
        action="store_true",
        default=True,
        help="Show cache statistics (default)",
    )
    parser.add_argument(
        "--clean-empty", action="store_true", help="Clean entries with empty results"
    )
    parser.add_argument(
        "--clean-malformed",
        action="store_true",
        help="Clean entries with malformed JSON",
    )
    parser.add_argument(
        "--clean-model",
        metavar="MODEL_NAME",
        help="Clean all entries for specific model",
    )
    parser.add_argument(
        "--clean-all",
        action="store_true",
        help="Clean entire cache (use with caution!)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview actions without actually deleting",
    )
    parser.add_argument(
        "--backup", action="store_true", help="Create backup before cleaning"
    )
    parser.add_argument(
        "--backup-dir", metavar="DIR", help="Custom backup directory name"
    )

    args = parser.parse_args()

    # Initialize analyzer
    analyzer = CacheAnalyzer()

    # Scan cache
    analyzer.scan_cache()

    # Always show stats first
    analyzer.print_statistics()

    # Create backup if requested
    if args.backup:
        if not analyzer.backup_cache(args.backup_dir):
            print("❌ Backup failed. Aborting cleaning operations.")
            return 1

    # Perform cleaning operations
    total_cleaned = 0

    if args.clean_empty:
        total_cleaned += analyzer.clean_empty_results(args.dry_run)

    if args.clean_malformed:
        total_cleaned += analyzer.clean_malformed_json(args.dry_run)

    if args.clean_model:
        total_cleaned += analyzer.clean_model_cache(args.clean_model, args.dry_run)

    if args.clean_all:
        total_cleaned += analyzer.clean_all_cache(args.dry_run)

    # Final summary
    if total_cleaned > 0:
        action = "Would clean" if args.dry_run else "Cleaned"
        print(f"\n🎉 {action} {total_cleaned} cache entries total")
    elif any(
        [args.clean_empty, args.clean_malformed, args.clean_model, args.clean_all]
    ):
        print("\n✅ No cleaning was needed")

    return 0


if __name__ == "__main__":
    sys.exit(main())
