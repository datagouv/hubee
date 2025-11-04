# Pagy configuration for API pagination
# https://ddnexus.github.io/pagy-pre/guides/upgrade-guide/

# Default items per page
Pagy.options[:limit] = 50

# Limit configuration (replaces limit_extra and max_limit)
Pagy.options[:limit_key] = "per_page" # Accept per_page parameter (must be string, not symbol)
Pagy.options[:client_max_limit] = 100 # Maximum items per page allowed

# Overflow handling (now integrated by default)
# Empty pages served automatically, set raise_range_error: true to restore error-raising
# Use @pagy.in_range? to check validity instead of @pagy.overflow?

# Headers configuration (new API in pagy 43)
# Customize header names for API responses
# Map: page => current-page header, limit => page-limit header, etc.
Pagy.options[:headers_map] = {
  page: "X-Page",
  limit: "X-Per-Page",
  count: "X-Total",
  pages: "X-Total-Pages"
}
