# Load Redmine core test helper and plugin support files.
require File.expand_path('../../../test/test_helper', __dir__)

# Redmine's test environment uses :null_store (5.1 through 7.0.1). These
# tests seed OIDC discovery with Rails.cache.write; a null store drops that
# write and fetch_discovery then opens a TCP connection to the issuer.
# Swap in a process-local memory store so the suite stays offline.
# Token exchange remains stubbed in the tests that need a token response.
memory_cache = ActiveSupport::Cache.lookup_store(:memory_store)
Rails.cache = memory_cache
