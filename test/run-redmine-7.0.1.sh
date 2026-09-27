#!/usr/bin/env bash
# Run this plugin's MiniTest inside the official redmine:7.0.1 image (SQLite).
# The image omits the Gemfile :test group; this script installs it.
# Token exchange stays stubbed in test/ — the container does not call an IdP.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${REDMINE_IMAGE:-redmine:7.0.1}"

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi

"${DOCKER[@]}" run --rm --user root \
  -e SECRET_KEY_BASE=redmine-sso-suite-test-secret \
  -e REDMINE_LANG=en \
  -v "$PLUGIN_DIR:/opt/plugin:ro" \
  --entrypoint bash \
  "$IMAGE" \
  -lc 'set -euo pipefail
cd /usr/src/redmine
rm -rf plugins/redmine_sso_suite
cp -a /opt/plugin plugins/redmine_sso_suite
mkdir -p db tmp log
cat > config/database.yml <<YAML
production:
  adapter: sqlite3
  database: db/redmine.sqlite3
development:
  adapter: sqlite3
  database: db/redmine_dev.sqlite3
test:
  adapter: sqlite3
  database: db/redmine_test.sqlite3
YAML
# The image pins BUNDLE without to development:test. Install the test group.
bundle config unset --local without || true
bundle config unset --global without || true
rm -f .bundle/config
bundle config set --local without development
bundle install
export RAILS_ENV=test
bundle exec rake db:migrate redmine:plugins:migrate
bundle exec rake redmine:plugins:test NAME=redmine_sso_suite
'
