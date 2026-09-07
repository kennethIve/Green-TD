# Web / GitHub Pages

## Local export

1. Godot 4.3+ with **Web (nothreads)** export template
2. Preset `Web` in `export_presets.cfg` (`thread_support=false` for Pages without COOP/COEP)
3. Export to `build/web/index.html`

## Deploy

```bash
# from repo root after export
git checkout --orphan gh-pages
git reset
cp -r build/web/* .
touch .nojekyll
git add -A && git commit -m "Deploy web sample"
git push -u origin gh-pages
```

Then enable Pages on branch `gh-pages` / root.

Site will be: `https://kennethive.github.io/Green-TD/`
