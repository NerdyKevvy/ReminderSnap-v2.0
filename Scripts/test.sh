#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
mkdir -p .build/module-cache .build/cache
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
swift run --disable-sandbox --cache-path .build/cache ReminderSnapTests --reading
swift run --disable-sandbox --cache-path .build/cache remindersnap-cli --self-test
