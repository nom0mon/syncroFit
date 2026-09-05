# Android responsive layout standard

SyncroFit supports Android windows from 320–1,280 logical pixels (dp). Screens must use `ResponsiveStandards`, `ResponsiveConstrainedPage`, `AdaptiveGridList`, and `ResponsiveCard` from `lib/shared/widgets/responsive_layout.dart` rather than declaring screen-local breakpoints.

## Widths and spacing

| Class | Width | Page padding | Chart labels |
| --- | ---: | ---: | --- |
| Compact | below 360 dp (supported from 320 dp) | 16 dp | short labels, sampled to at most 4 |
| Standard | 360–599 dp | 20 dp | abbreviated labels, sampled to at most 6 |
| Tablet | 600–839 dp | 24 dp | full labels, sampled to at most 8 |
| Large | 840 dp and above (supported through 1,280 dp) | 32 dp | full labels, sampled to at most 12 |

The readable page column is centered and limited to 840 dp. Use the existing 4/8/16/24/32/48 dp `AppSpacing` scale for gaps. Every interactive control must expose a hit region at least 48 × 48 dp, even when its visible icon is smaller.

`AdaptiveGridList` computes columns from available width and a 240 dp default minimum card width. It renders one vertical column whenever another column would make cards too narrow; otherwise it creates equal-width wrapping columns with 16 dp gaps. Keep scrolling at the page level rather than nesting a scroll view in the helper. Charts and paired stat cards use the same one-column fallback when readable side-by-side content does not fit.

## Text behavior

Text behavior must be intentional and preserve the complete value in semantics:

- User-generated bodies, descriptions, comments, and instructions wrap naturally. Do not ellipsize them in detail views.
- Preview cards may truncate a user-generated body only with an explicit line limit (normally 2–3 lines) and `TextOverflow.ellipsis`; the full text must be available after opening the item.
- Member names and other short identifiers wrap to two lines where row height can grow. Dense list rows may use a documented single-line ellipsis only when the full value is available in the destination view or an accessible label/tooltip.
- Translated headings, settings labels, field labels, validation messages, and primary actions wrap. Do not give critical instructions or actions a single-line ellipsis.
- Metadata with a stable compact format (dates, counts, durations) may remain one line. If it competes with user text, wrap the row or move metadata below instead of clipping either value.
- Test user-generated and translated text at 200% system font scale. A primary action must remain visible or reachable by scrolling.

Chart widgets use `chartLabelDensityFor` to choose full, abbreviated, or sparse wording and `chartLabelStrideFor` to sample labels. Omitted visual labels do not remove data from the chart's accessible semantic summary.
