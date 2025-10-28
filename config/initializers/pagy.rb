# Pagy configuration for API pagination
# https://ddnexus.github.io/pagy/docs/api/pagy

require "pagy/extras/limit"
require "pagy/extras/headers"
require "pagy/extras/overflow"

# Default items per page
Pagy::DEFAULT[:limit] = 50

# Limit extra configuration
Pagy::DEFAULT[:limit_param] = :per_page # Accept per_page parameter
Pagy::DEFAULT[:limit_max] = 100 # Maximum items per page allowed

# Overflow extra: return empty page instead of raising exception
Pagy::DEFAULT[:overflow] = :empty_page

# Headers extra configuration
# Customize header names for API responses
Pagy::DEFAULT[:headers] = {
  page: "X-Page",
  limit: "X-Per-Page",
  count: "X-Total",
  pages: "X-Total-Pages"
}

Pagy::DEFAULT.freeze
