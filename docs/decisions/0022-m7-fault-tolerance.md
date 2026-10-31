# M7.2 Bounds and high contrast

## Status

Accepted for the source tree. CPU, GPU, suspend, and hotplug were not measured.

## Decision

- Spotlight shows at most 24 search rows. Ranking still scores the whole catalog. The idle grid stays at 12 applications.
- A notification burst keeps at most 4 banners and 40 history rows.
- `appearance.contrast` is `standard` or `high`. High uses black or white theme text. A manual hex still wins. Automatic text still follows a png sample. Reduced motion already sets open, close, and hover durations to 0.

## Consequences

A search with more than 24 matches hides the rest. There is no separate high-contrast wallpaper mode. This change does not report CPU or GPU numbers from a session.
