# YouTube Factory Board
Production board for the YouTube Factory channels: channel tabs, six-stage pipeline with approval gates, swipe file of outlier videos.
Static page on GitHub Pages; data in Supabase, readable and editable only by the owner's signed-in account (Row Level Security).
- `index.html` — the board (no build step)
- `supabase/schema.sql` — tables (channels, videos, swipe, jobs, runner), access policy, realtime
- Production desk: Run buttons queue jobs in `jobs`; the laptop runner (YouTube Factory\shared\runner\START-RUNNER.bat) executes them, streams progress/logs back and syncs beats, rights ledger, claims and renders to each card.
