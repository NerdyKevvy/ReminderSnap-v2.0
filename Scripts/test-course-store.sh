#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
swift build --disable-sandbox --cache-path .build/cache --target ReminderSnapCore
binary_dir="$(swift build --disable-sandbox --cache-path .build/cache --show-bin-path)"
swiftc -parse-as-library -D DEBUG -I "$binary_dir" -I "$binary_dir/Modules" \
  -module-cache-path "$project_dir/.build/module-cache" \
  "$binary_dir/ReminderSnapCore.o" Sources/ReminderSnapApp/PlannerStore.swift \
  Tests/ReminderSnapAppTests/CourseStoreCheck.swift -o .build/course-store-check
REMINDERSNAP_LOCAL_ONLY=1 .build/course-store-check
