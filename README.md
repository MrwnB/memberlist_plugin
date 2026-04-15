# Discourse Memberlist Plugin

Adds a public `/memberlist` page to Discourse that shows:

- all non-automatic closed groups
- one section per group
- the members inside each group
- a top navigation item labeled `Memberlist`

The page is backed by a proper plugin route and JSON endpoint, so it does not rely on theme workarounds like `custom_homepage`.

This version intentionally ignores normal group visibility restrictions so the page can show closed-group memberships publicly.
